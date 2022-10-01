# JQL (Jira Query Language)

My unresolved and not deferred issues:
```jql
assignee = currentUser() AND resolution = Unresolved AND status != Deferred ORDER BY key
```

My unresolved deferred issues:
```jql
assignee = currentUser() AND resolution = Unresolved status = Deferred ORDER BY key
```

Unresolved issues I watch:
```jql
(assignee is EMPTY OR assignee not in (currentuser())) AND watcher in (currentuser()) AND statusCategory != Done ORDER BY created DESC
```

Issues from my project:
```jql
project = <PROJECT_NAME> AND resolution = Unresolved ORDER BY updated DESC, priority DESC
```

List open sprints:
```jql
sprint in (openSprints())
```

MongoDB Jira Query example:
```
project = SERVER AND status = Open AND priority = "Minor - P4" ORDER BY priority ASC, createdDate DESC
```
