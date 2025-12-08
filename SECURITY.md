# Security Policy

## Supported Versions

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@viablesystems.dev**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include the following information:

- Type of issue (e.g. remote code execution, SQL injection, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

This information will help us triage your report more quickly.

## What to Expect

- **Acknowledgment**: We'll acknowledge receipt of your vulnerability report within 48 hours
- **Updates**: We'll keep you updated on our progress in addressing the vulnerability
- **Credit**: We'll credit you in the security advisory (unless you prefer to remain anonymous)
- **Disclosure**: We follow coordinated disclosure practices

## Security Considerations When Using Scout

### User-Provided Objective Functions

**Critical**: Scout executes user-provided objective functions during optimization. When deploying Scout in multi-tenant or untrusted environments:

1. **Sandbox objective functions**: Use isolated execution environments
2. **Resource limits**: Set memory and CPU limits to prevent DoS
3. **Timeout enforcement**: Use Scout's built-in timeout parameter
4. **Input validation**: Validate all search space parameters

Example safe configuration:

```elixir
# Enforce timeout
Scout.Easy.optimize(
  objective,
  search_space,
  timeout: 60_000  # 60 seconds max
)

# In production: run in isolated process with resource limits
```

### Dashboard Security

The Scout dashboard (Phoenix LiveView) should be protected in production:

1. **Authentication**: Implement authentication (e.g., `pow`, `guardian`)
2. **Authorization**: Restrict access to study management endpoints
3. **HTTPS**: Always use HTTPS in production
4. **Rate limiting**: Implement rate limiting on dashboard endpoints

Example protection:

```elixir
# In your router.ex
pipeline :protected do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :require_authentication  # Your auth plug
  plug :require_admin_role      # Role-based access
end

scope "/scout", ScoutDashboard do
  pipe_through :protected
  # ... dashboard routes
end
```

### Database Security

When using PostgreSQL storage:

1. **Least privilege**: Use dedicated database user with minimal permissions
2. **Connection encryption**: Use SSL/TLS for database connections
3. **Secrets management**: Store credentials in environment variables or secret managers
4. **Prepared statements**: Scout uses Ecto which prevents SQL injection

### Distributed Optimization Security

When running distributed optimization across nodes:

1. **Node authentication**: Use Erlang cookie or TLS node distribution
2. **Network isolation**: Run on private networks or VPN
3. **Encrypted communication**: Enable TLS distribution
4. **Access control**: Restrict which nodes can join the cluster

Example secure node configuration:

```bash
# Use TLS distribution
iex --name scout@host --erl "-proto_dist inet_tls" -S mix
```

## Known Limitations

1. **Objective function safety**: Scout cannot prevent malicious code in user-provided objectives
2. **Resource consumption**: Long-running trials can consume significant resources
3. **Serialization**: Elixir term serialization (`:erlang.binary_to_term/1`) is used internally - do not deserialize untrusted data

## Security Best Practices

1. **Review objective functions**: Audit all optimization objectives before production use
2. **Monitor resource usage**: Set up alerts for abnormal CPU/memory usage
3. **Regular updates**: Keep Scout and dependencies up to date
4. **Least privilege**: Run Scout processes with minimal system permissions
5. **Audit logs**: Enable logging for study creation and trial execution

## Vulnerability Disclosure Timeline

1. **Day 0**: Security vulnerability reported
2. **Day 1-2**: Initial response and triage
3. **Day 3-14**: Develop and test patch
4. **Day 15**: Release security patch
5. **Day 16-30**: Coordinated public disclosure

## Security Hall of Fame

We're grateful to the following researchers for responsibly disclosing security issues:

- _No vulnerabilities reported yet_

## Additional Resources

- [Elixir Security Resources](https://elixir-lang.org/blog/2022/12/14/secure-coding-and-deployment-hardening/)
- [Phoenix Security Guide](https://hexdocs.pm/phoenix/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

Last updated: December 7, 2025
