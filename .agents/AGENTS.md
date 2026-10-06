# Agent Guidelines & Rules

## 1. No Unrequested Mock or Fallback Data (Strict Rule)

- **Do NOT introduce mock, simulated, or fallback data** in production code (`lib/`) unless explicitly and unambiguously instructed by the user.
- **Fail Transparently**: When an external API, remote service, network endpoint, or Model Context Protocol (MCP) server is offline, unreachable, or returns an error:
  - Return explicit error states, exceptions, or failure results (e.g., `isSuccess: false` with accurate error messages).
  - Do **not** silently catch errors and return fake/simulated "success" payloads.
  - Do **not** inject synthetic fallback tools, sample items, or placeholder records when discovery or fetch operations return empty or fail.
- **No Embedded Simulation Engines**: Never build internal `switch` statements or mock data generators inside production services or clients (e.g., simulating weather, media searches, or database queries) to mask missing backend integrations.

## 2. Proper Separation of Test Mocks

- Mock data and fake responses belong **strictly within test suites** (`test/`) using proper mocking libraries (e.g., `mocktail`, `mockito`, or HTTP mock adapters).
- Never pollute production service classes with mock data branches for the sake of tests. Use dependency injection and mock interfaces instead.

## 3. Transparency & Requirement Clarification

- If a backend endpoint, data schema, or remote capability is not yet implemented or unavailable:
  - Implement real error handling for the unavailable state.
  - Ask the user for guidance or clarification if uncertain, rather than inventing mock implementations.
