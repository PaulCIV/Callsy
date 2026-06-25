import { apiFetch } from "./client";

export type AuthUser = {
  _id: string;
  email: string;
};

export type AuthResponse = {
  ok: true;
  user: AuthUser;
};

export async function signup(email: string, password: string) {
  return apiFetch<AuthResponse>("/auth/signup", {
    method: "POST",
    json: { email, password }
  });
}

export async function login(email: string, password: string) {
  return apiFetch<AuthResponse>("/auth/login", {
    method: "POST",
    json: { email, password }
  });
}

export async function me() {
  return apiFetch<AuthResponse>("/auth/me", {
    method: "GET"
  });
}

export async function logout() {
  return apiFetch<{ ok: true }>("/auth/logout", {
    method: "POST"
  });
}