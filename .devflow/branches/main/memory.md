# DevFlow Memory

## Stack

- Runtime: nodejs
- Frontend: unknown

## Graph

route:src.routes.+pagesvelte: Home page route
entity:Entities.Commentcs: Soft-deletable content unit attached to a story
service:Services.CommentServicecs: Owns all comment mutations
contract:Contracts.CommentCreatedEventcs: Event emitted when a new comment is created
unknown:src.lib.utils.slugts: URL slug utility