# Contributing to Claude Turbo Search

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## How to Contribute

1. **Fork the repository** on GitHub
2. **Create a feature branch** from the main branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** and commit them with clear commit messages
4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
5. **Open a Pull Request** on the main repository with a clear description of your changes

## Development Setup

### Clone the repository

```bash
git clone https://github.com/your-username/claude-turbo-search.git
cd claude-turbo-search
```

### Running tests

Before submitting changes, ensure all tests pass:

```bash
./tests/run_tests.sh
```

To run specific tests:

```bash
./tests/run_tests.sh test_name
```

## Code Style

This project follows Bash best practices:

- Use meaningful variable and function names
- Add comments for complex logic
- Follow consistent indentation (2 spaces)
- Use shellcheck to lint your code

### Linting with ShellCheck

Before committing, run ShellCheck on your scripts:

```bash
shellcheck script.sh
```

To check all shell scripts in the project:

```bash
find . -name "*.sh" -type f | xargs shellcheck
```

Common issues to avoid:
- Always quote variables: `"$var"` instead of `$var`
- Use `[[ ]]` instead of `[ ]` for conditionals
- Avoid using `eval` when possible
- Use local variables in functions

## Testing Changes

### Local Testing

To test your changes locally:

1. Make sure your changes don't break existing functionality:
   ```bash
   ./tests/run_tests.sh
   ```

2. Test the CLI manually with sample inputs:
   ```bash
   ./claude-turbo-search "your search query"
   ```

3. Run ShellCheck on modified scripts:
   ```bash
   shellcheck your_modified_script.sh
   ```

### Creating Tests

If adding new features, please include tests. Tests should be placed in the `tests/` directory and follow the naming convention `test_*.sh`.

## Reporting Bugs

Found a bug? Please report it on GitHub:

1. Go to the [Issues page](https://github.com/iagocavalcante/claude-turbo-search/issues)
2. Click **New Issue**
3. Provide:
   - A clear, descriptive title
   - Steps to reproduce the issue
   - Expected behavior
   - Actual behavior
   - Your environment (OS, Bash version, etc.)

Example:
```
Title: Search fails with special characters in query

Steps to reproduce:
1. Run ./claude-turbo-search "test & query"
2. Observe error

Expected: Should escape special characters
Actual: Bash syntax error

Environment: macOS 12, Bash 5.1
```

---

Happy contributing!
