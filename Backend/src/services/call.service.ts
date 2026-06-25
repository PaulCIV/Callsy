export function buildFollowupMessage(
  template: string,
  data: {
    caller?: string;
    business?: string;
    link?: string;
  }
) {
  let msg = String(template ?? "");

  msg = msg.split("{{caller}}").join(data.caller ?? "");
  msg = msg.split("{{business}}").join(data.business ?? "");
  msg = msg.split("{{link}}").join(data.link ?? "");

  return msg;
}

export function appendMenuOptions(message: string, options: string[]) {
  if (!options || options.length === 0) return message;

  const menu = options
    .map((opt, i) => `${i + 1}. ${opt}`)
    .join("\n");

  return `${message}\n\n${menu}`;
}