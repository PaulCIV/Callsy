const API_BASE = "http://localhost:3000";

type RequestOptions = RequestInit & {
  json?: unknown;
};

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { json, headers, ...rest } = options;

  const response = await fetch(`${API_BASE}${path}`, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(headers || {})
    },
    ...rest,
    body: json !== undefined ? JSON.stringify(json) : rest.body
  });

  const contentType = response.headers.get("content-type") || "";
  const data = contentType.includes("application/json")
    ? await response.json()
    : await response.text();

  if (!response.ok) {
    const message =
      typeof data === "object" && data !== null && "error" in data
        ? String((data as any).error)
        : "Request failed";
    throw new Error(message);
  }

  return data as T;
}