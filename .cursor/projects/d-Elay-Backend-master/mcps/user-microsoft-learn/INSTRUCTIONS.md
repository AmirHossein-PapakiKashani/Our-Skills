# Microsoft Learn MCP Server

This server gives structured access to official Microsoft and Azure documentation via three tools:

## Tools

### microsoft_docs_search
Search official documentation and return up to 10 concise, high-quality content chunks (max 500 tokens each), including title, URL, and excerpt.

- Use first to get a quick, reliable overview
- Ideal for grounding answers in Microsoft knowledge

### microsoft_code_sample_search
Search for code snippets and examples in official Microsoft Learn documentation and return up to 20 relevant, high-quality code samples.

- Use when you need to provide sample Microsoft/Azure related code in your answers.  
- Ideal for generating code snippets or practical implementation examples.  
- Optional parameter `language` can filter results. 

### microsoft_docs_fetch
Fetch and convert full Microsoft documentation pages to markdown.

- Use after search when you need full content from a specific URL
- Required for detailed tutorials, troubleshooting, prerequisites, code samples, or when search results are incomplete or outdated

## Workflow

1. Use `microsoft_docs_search` to find relevant documents.
2. If you need code examples or practical snippets, use `microsoft_code_sample_search`.
3. If deeper or complete information is needed, use `microsoft_docs_fetch`.

**Search gives breadth. Code Sample Search gives practical examples. Fetch gives depth.**

All content comes from Microsoft Learn or official sources, returned in clean markdown format.