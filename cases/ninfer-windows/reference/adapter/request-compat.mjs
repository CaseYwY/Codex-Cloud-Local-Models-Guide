// llama.cpp WebUI names the reasoning cap differently from NInfer RC3.
// Preserve messages, raw tool arguments and every other request field.
export function normalizeChatRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body) ||
      !Object.hasOwn(body, 'thinking_budget_tokens')) return body;
  const normalized = { ...body };
  if (!Object.hasOwn(normalized, 'thinking_budget'))
    normalized.thinking_budget = normalized.thinking_budget_tokens;
  delete normalized.thinking_budget_tokens;
  return normalized;
}

export function normalizeChatBytes(bytes) {
  if (!bytes.includes('"thinking_budget_tokens"')) return bytes;
  const body = JSON.parse(bytes.toString('utf8'));
  const normalized = normalizeChatRequest(body);
  return normalized === body ? bytes : Buffer.from(JSON.stringify(normalized));
}

// Codex speaks Responses. These aliases select the already tested local budgets.
// Other Responses clients retain their original request, including tool history.
export function normalizeResponsesBytes(bytes, model) {
  const body = JSON.parse(bytes.toString('utf8'));
  const preset = {
    'ninfer-minsi': [16384, 24576],
    'ninfer-qiongli': [32768, 40960]
  }[body.model];
  if (!preset) return bytes;
  const [budget, output] = preset;
  return Buffer.from(JSON.stringify({
    ...body, model,
    reasoning: { ...body.reasoning, effort: 'xhigh' },
    thinking_budget: budget,
    max_output_tokens: output,
    chat_template_kwargs: {
      ...body.chat_template_kwargs, enable_thinking: true,
      preserve_thinking: true, reasoning_effort: 'xhigh'
    }
  }));
}

export function normalizePropsPath(value, model) {
  const url = new URL(value, 'http://127.0.0.1');
  if (url.pathname !== '/props') return value;
  if ([...url.searchParams.keys()].some(key => !['model', 'autoload'].includes(key))) return value;
  if (url.searchParams.has('model') && url.searchParams.get('model') !== model) return value;
  return '/props';
}
