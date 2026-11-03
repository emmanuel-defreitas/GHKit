# Pagination

Iterate over list endpoints and load pages only as you need them.

## Overview

List endpoints return ``Paginated``, an `AsyncSequence` of items. It works the same for GitHub's
page-number endpoints and its cursor-based ones.

```swift
let acme = github.projects(.organization("acme"))

// Lazy: pages load as you iterate. Breaking out of the loop stops loading.
for try await item in acme.items(of: 1) {
    print(item.id)
}

// Everything, or just the first N
let first100 = try await acme.items(of: 1).collect(limit: 100)
```

### Load more on demand

For a "Load more" button, keep the request and ask for one ``Page`` at a time:

```swift
let request = acme.itemsRequest(of: 1)
var page = try await github.page(request)

if let next = page.next {
    page = try await github.page(request, at: next)
}
```

Each ``Page`` carries its items, the ``PageCursor`` for the next and previous pages,
and the ``ResponseMetadata`` of the response that produced it.

### Paginate your own requests

``GitHubClient/paginate(_:)`` turns any ``GitHubRequest`` for a list into a ``Paginated`` sequence.
See <doc:CallingAnyEndpoint>.
