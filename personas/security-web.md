# Security: Web & API Applications

Domain-specific security considerations for web applications, REST/GraphQL APIs, and backend services.

> **Activate when:** Auditing Python, Node.js, Go, Ruby, or other web/API codebases.

---

## Unique Threat Model

Web applications face:

- **Public exposure:** Internet-accessible attack surface
- **Diverse inputs:** Forms, headers, cookies, files, WebSockets
- **Session complexity:** Stateless protocols with stateful semantics
- **Third-party risk:** Client-side dependencies, OAuth providers, APIs

---

## Injection Attacks

### SQL Injection

- [ ] All queries use parameterized statements / prepared statements
- [ ] No string concatenation for query building
- [ ] ORM used correctly (no `raw()` with user input)
- [ ] Database user has minimal required permissions

**Pattern to flag:**

```python
# VULNERABLE
query = f"SELECT * FROM users WHERE id = {user_id}"

# SAFE
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

### Command Injection

- [ ] Shell execution avoided entirely where possible
- [ ] If required: input validated against strict allow-list
- [ ] Arguments passed as array, not string (avoids shell interpretation)
- [ ] No user input in command string

### XSS (Cross-Site Scripting)

- [ ] Output encoding applied contextually (HTML, JS, URL, CSS)
- [ ] Template engines auto-escape by default
- [ ] `dangerouslySetInnerHTML` / `innerHTML` avoided or sanitized
- [ ] CSP headers configured and enforced

### Path Traversal

- [ ] File paths validated against allowed directories
- [ ] Canonicalization before comparison (`realpath`)
- [ ] No `../` sequences reach filesystem

---

## Authentication

### Password Handling

- [ ] Passwords hashed with bcrypt, argon2, or scrypt (cost factor appropriate)
- [ ] No plaintext passwords in logs, errors, or storage
- [ ] Password complexity requirements enforced
- [ ] Breached password detection (HaveIBeenPwned API)

### Session Management

- [ ] Session tokens generated with CSPRNG (≥128 bits entropy)
- [ ] HttpOnly, Secure, SameSite flags on session cookies
- [ ] Session invalidated on logout
- [ ] Session rotation on privilege change (login, password change)
- [ ] Absolute and idle timeout enforced

### Multi-Factor Authentication

- [ ] TOTP implementation uses standard algorithm
- [ ] Recovery codes generated securely and stored hashed
- [ ] MFA bypass not possible via password reset flow

### OAuth/OIDC

- [ ] State parameter validated (CSRF protection)
- [ ] Redirect URI strictly validated (no open redirect)
- [ ] Token validation includes issuer, audience, expiration
- [ ] Authorization code used only once

---

## Authorization

### Access Control

- [ ] Authorization checked on every request (not just UI hiding)
- [ ] Resource ownership verified (`resource.owner_id == current_user.id`)
- [ ] Role checks use server-side session, not client-provided claims
- [ ] Admin endpoints on separate authentication

### IDOR Prevention

Trace every resource access:

```
Request → Extract resource_id → Load resource → Verify access → Return
                                               ↳ If no verify: VULNERABILITY
```

- [ ] All resource endpoints verify ownership/permission
- [ ] IDs are unpredictable (UUIDs preferred over sequential)
- [ ] Bulk/list endpoints filter by user context

---

## API-Specific Concerns

### Rate Limiting

- [ ] Rate limits on authentication endpoints
- [ ] Rate limits on expensive operations
- [ ] Limits per user/IP/API key
- [ ] Graceful degradation under load

### Input Validation

- [ ] Request body validated against schema (JSON Schema, Zod, Pydantic)
- [ ] Content-Type header validated
- [ ] Request size limits enforced
- [ ] File upload validation (type, size, content)

### GraphQL Specific

- [ ] Query depth limiting
- [ ] Query complexity analysis
- [ ] Introspection disabled in production (or access-controlled)
- [ ] Field-level authorization

---

## CSRF & CORS

### CSRF Protection

- [ ] State-changing requests require anti-CSRF token
- [ ] Token validated server-side
- [ ] SameSite cookie attribute set

### CORS Configuration

- [ ] No wildcard (`*`) origin on credentialed endpoints
- [ ] Allowed origins explicitly listed
- [ ] Preflight caching appropriate
- [ ] Sensitive headers not exposed

---

## Server-Side Request Forgery (SSRF)

When application makes HTTP requests based on user input:

- [ ] URL scheme restricted (http/https only)
- [ ] Internal IP ranges blocked (127.0.0.1, 10.x, 169.254.x, etc.)
- [ ] DNS rebinding protection (resolve before request)
- [ ] Redirect following disabled or limited

---

## Security Headers

- [ ] `Content-Security-Policy` — XSS mitigation
- [ ] `X-Content-Type-Options: nosniff` — MIME sniffing prevention
- [ ] `X-Frame-Options` or CSP `frame-ancestors` — Clickjacking prevention
- [ ] `Strict-Transport-Security` — HTTPS enforcement
- [ ] `Referrer-Policy` — Prevent referrer leakage

---

## Logging & Monitoring

- [ ] Authentication events logged (success, failure, lockout)
- [ ] Authorization failures logged
- [ ] Sensitive data NOT logged (passwords, tokens, PII)
- [ ] Log injection prevented (newlines, control chars escaped)
- [ ] Alerting on anomalous patterns

---

## Checklist Summary

| Category  | Items                                            |
| :-------- | :----------------------------------------------- |
| Injection | Parameterized queries, no shell, output encoding |
| AuthN     | Strong hashing, secure sessions, MFA             |
| AuthZ     | Every-request checks, IDOR prevention            |
| API       | Rate limiting, schema validation, GraphQL limits |
| CSRF/CORS | Tokens, SameSite, strict origins                 |
| SSRF      | URL validation, internal IP blocking             |
| Headers   | CSP, HSTS, X-Frame-Options                       |
| Logging   | Security events, no sensitive data               |
