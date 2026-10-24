/**
 * dsh-goat-vision — multi-route vision bridge for a text-only V4-Pro brain.
 *
 * Registers one NEW provider route per entry in `config.routes`. Each route
 * wraps an existing adapter (innerProvider) and:
 *   - `resolveModel` claims `inputModalities: ['text', 'image']` so the Web
 *     attachment preflight and the `read_image` capability gate admit images;
 *   - `stream` transcribes every image block to text through an OpenAI-compatible
 *     VLM (the route's `model` @ `baseURL`), then delegates the text-only
 *     conversation to the wrapped adapter.
 *
 * Stock routes (see cordis.patch.yml):
 *   1. `goat-vision`     — GOAT / Command Code: brain deepseek-v4-pro, eyes deepseek-v4.1-flash.
 *   2. `deepseek-vision` — official DeepSeek: brain deepseek-v4-pro, eyes deepseek-flash (V4.1).
 *
 * Why this plugin instead of dsh-vision-proxy: dsh-vision-proxy is built for the
 * single-route `deepseek-official` adapter and passes its own route id straight
 * through to the inner adapter. The pi-ai adapter keys every method off the
 * provider string, so that passthrough fails. This plugin translates the outer
 * route id to the configured inner route before delegating, for any adapter.
 *
 * @module dsh-goat-vision
 */
import { createHash } from 'node:crypto';

export const name = 'dsh-goat-vision';
export const inject = ['llm', 'attachments'];

const ROUTE_DEFAULTS = {
    providerId: 'goat-vision',
    innerProvider: 'commandcode',
    displayName: '自动识图',
    baseURL: 'https://api.commandcode.ai/provider/v1',
    model: 'deepseek/deepseek-v4.1-flash',
    apiKey: '',
    apiKeyEnv: 'COMMANDCODE_API_KEY',
    maxTokens: 4096,
    timeoutMs: 120_000,
    reasoningEffort: 'low',
    marker: '[图片转译]',
    failureMode: 'placeholder',
};

const CACHE_CAP = 200;
const FAILURE_COOLDOWN_MS = 60_000;

const TRANSCRIBE_PROMPT = `You are an image-to-text transcription service. The recipient is a text-only LLM that cannot see the image. Produce a faithful, complete text rendition covering:
1. ALL visible text, verbatim, in its original language (OCR).
2. The overall layout and structure (positioning, sections, hierarchy).
3. Notable visual elements: objects, people, colors, icons, UI components, charts or tables and the data they show.
4. Any other detail that matters (style, logos, numbers, timestamps, URLs).
Be precise and thorough; prefer completeness over brevity. Output only the transcription, no preamble.`;

/** Recursively detect image blocks, walking tool-result content. */
function hasImage(content) {
    return content.some((block) => block.type === 'image'
        || (block.type === 'tool-result' && hasImage(block.content)));
}

/**
 * Resolve the VLM key: literal config → credentials service → environment.
 * @returns {Promise<string>}
 */
async function resolveKey(ctx, config) {
    if (config.apiKey) return config.apiKey;
    const envName = config.apiKeyEnv ?? ROUTE_DEFAULTS.apiKeyEnv;
    const credentials = ctx?.get?.('credentials');
    if (credentials !== undefined && credentials !== null) {
        try {
            const hit = await credentials.resolve(envName);
            if (hit !== undefined && hit !== null && hit.value !== undefined && String(hit.value).length > 0) {
                return String(hit.value);
            }
        } catch {
            // fall through to the environment
        }
    }
    const fromEnv = process.env[envName] ?? process.env.VISION_API_KEY ?? process.env.DASHSCOPE_API_KEY ?? '';
    if (fromEnv !== '') return fromEnv;
    throw new Error(`dsh-goat-vision: no VLM API key for route "${config.providerId}". Set "${envName}" in credentials (.credentials.yaml) or export VISION_API_KEY.`);
}

/** Transcribe one image (content-hash cached); never throws in placeholder mode. */
async function transcribeOne(ctx, config, ref, signal, cache) {
    const attachments = ctx.get('attachments');
    const stored = await attachments.readImage(ref, signal);
    const data = stored.data;
    const hash = createHash('sha256').update(data).digest('hex');
    const key = `sha256:${hash}`;
    const hit = cache.get(key);
    if (hit !== undefined) {
        if (hit.text !== undefined) return { text: hit.text };
        if (hit.failedUntil > Date.now()) return { text: `[图片转译失败: ${hit.reason}]`, failed: true };
        cache.delete(key); // stale failure marker — retry now
    }
    try {
        const mediaType = stored.ref?.mediaType ?? 'image/png';
        const dataUrl = `data:${mediaType};base64,${Buffer.from(data).toString('base64')}`;
        const url = `${config.baseURL.replace(/\/+$/, '')}/chat/completions`;
        const apiKey = await resolveKey(ctx, config);
        const res = await fetch(url, {
            method: 'POST',
            headers: {
                'content-type': 'application/json',
                authorization: `Bearer ${apiKey}`,
            },
            body: JSON.stringify({
                model: config.model,
                max_tokens: config.maxTokens,
                ...(config.reasoningEffort ? { reasoning_effort: config.reasoningEffort } : {}),
                messages: [{
                    role: 'user',
                    content: [
                        { type: 'image_url', image_url: { url: dataUrl } },
                        { type: 'text', text: TRANSCRIBE_PROMPT },
                    ],
                }],
            }),
            signal: AbortSignal.any([AbortSignal.timeout(config.timeoutMs), ...(signal === undefined ? [] : [signal])]),
        });
        const body = await res.text();
        if (!res.ok) throw new Error(`transcription failed (HTTP ${res.status}): ${body.slice(0, 300)}`);
        let payload;
        try {
            payload = JSON.parse(body);
        } catch {
            throw new Error(`transcription failed, non-JSON response: ${body.slice(0, 200)}`);
        }
        const content = payload?.choices?.[0]?.message?.content;
        const text = typeof content === 'string'
            ? content
            : Array.isArray(content)
                ? content.map((part) => (part && typeof part.text === 'string' ? part.text : '')).filter(Boolean).join('\n')
                : '';
        const trimmed = (text ?? '').trim();
        if (trimmed === '') throw new Error('transcription failed, VLM returned no text');
        if (cache.size >= CACHE_CAP) cache.delete(cache.keys().next().value);
        cache.set(key, { text: trimmed });
        return { text: trimmed };
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (config.failureMode === 'placeholder') {
            const reason = message.slice(0, 200);
            cache.set(key, { failedUntil: Date.now() + FAILURE_COOLDOWN_MS, reason });
            return { text: `[图片转译失败: ${reason}]`, failed: true };
        }
        throw error;
    }
}

/** Replace image blocks with transcribed text, recursively. */
async function transcribeBlocks(ctx, config, blocks, signal, cache) {
    const out = [];
    for (const block of blocks) {
        if (block.type === 'image') {
            const { text } = await transcribeOne(ctx, config, block.attachment, signal, cache);
            out.push({ type: 'text', text: `${config.marker}\n${text}` });
        } else if (block.type === 'tool-result' && hasImage(block.content)) {
            out.push({ ...block, content: await transcribeBlocks(ctx, config, block.content, signal, cache) });
        } else {
            out.push(block);
        }
    }
    return out;
}

/** Transcribe all images in a message list; image-free messages pass through untouched. */
async function transcribeMessages(ctx, config, messages, signal, cache) {
    const out = [];
    for (const message of messages) {
        if (!hasImage(message.content)) {
            out.push(message);
            continue;
        }
        out.push({ ...message, content: await transcribeBlocks(ctx, config, message.content, signal, cache) });
    }
    return out;
}

/** Register one vision route wrapping `config.innerProvider`. */
function registerRoute(ctx, config) {
    const resolved = { ...ROUTE_DEFAULTS, ...config };
    const innerProvider = resolved.innerProvider;
    const cache = new Map();

    // Resolve the wrapped adapter LAZILY at request time. The inner provider
    // (e.g. a llm-pi-ai route) may not be registered yet at plugin-load time —
    // llm-pi-ai registers its adapters only after settings injection, so an
    // eager ctx.llm.registration() here would throw NO_ADAPTER and crash the
    // whole plugin tree. Note ctx.llm.registration() THROWS for unknown
    // providers (it does NOT return undefined), so every lookup is guarded.
    const inner = () => {
        const registration = ctx.llm.registration(innerProvider);
        if (registration === undefined || registration.adapter === undefined) {
            throw new Error(`dsh-goat-vision: no adapter registered for "${innerProvider}" (route "${resolved.providerId}")`);
        }
        return registration.adapter;
    };

    ctx.logger?.info?.(`dsh-goat-vision: route "${resolved.providerId}" (${resolved.displayName}) wraps "${innerProvider}" · VLM ${resolved.model} @ ${resolved.baseURL} · reasoningEffort ${resolved.reasoningEffort || '(off)'} · maxTokens ${resolved.maxTokens} · failureMode ${resolved.failureMode} · apiKeyEnv ${resolved.apiKeyEnv} (key itself is never logged)`);
    ctx.logger?.info?.('dsh-goat-vision: PRIVACY NOTICE — image bytes are sent over HTTPS to the configured VLM endpoint for transcription.');

    const proxy = {
        providerInfo: (provider) => ({ id: provider, name: resolved.displayName }),
        providerRetryPolicy: () => {
            // Runs at registerAdapter() time, possibly before the inner adapter
            // exists — must never throw. Fall back to the default retry policy.
            try { return inner().providerRetryPolicy?.(innerProvider) ?? undefined; } catch { return undefined; }
        },
        listModels: async (provider) => {
            const models = await inner().listModels(innerProvider);
            // Re-stamp the outer route so the picker stays consistent.
            return models.map((model) => ({ ...model, provider }));
        },
        resolveModel: async (provider, model, signal) => {
            const info = await inner().resolveModel(innerProvider, model, signal);
            // The key trick: claim image input so attachment preflight and the
            // read_image gate admit images; transcription happens in stream().
            return { ...info, provider, inputModalities: ['text', 'image'] };
        },
        prepareCall: async (provider, model, signal) => ({
            model: await proxy.resolveModel(provider, model, signal),
            stream: (options) => proxy.stream(options),
        }),
        stream: async function* (options) {
            const messages = await transcribeMessages(ctx, resolved, options.messages, options.signal, cache);
            yield* inner().stream({ ...options, provider: innerProvider, messages });
        },
    };

    ctx.llm.registerAdapter([resolved.providerId], proxy);
}

export function apply(ctx, config = {}) {
    const routes = Array.isArray(config.routes) && config.routes.length > 0 ? config.routes : [config];
    for (const route of routes) registerRoute(ctx, route);
}
