# Git

Remove all untracked files:
```shell
$ git clean -fxdq
```

Get the latest master:
```shell
$ git checkout master
$ git fetch --all -pt
$ git rebase
$ git submodule update --init --recursive
```

Add changes to tracked file or all files:
```shell
$ git add -u
$ git add --all
```

Evaluate the changes introduced by a feature branch:
```shell
$ git fetch -apt
$ git difftool --dir-diff --no-symlinks origin/master...my_feature_branch &
$ git difftool --dir-diff --no-symlinks origin/master...origin/their_feature_brach &
$ git vdiff origin/master...my_feature_branch &
$ git vdiff origin/master...origin/their_feature_brach &
```

Show what changed:
```shell
$ git status
$ git status -sbu
```

Manually merge a feature branch without creating a merge commit:
```shell
$ git checkout master
$ git merge --no-ff -m "Merge my_feature_branch into master" my_feature_branch
```

Manually resolve merge conflicts:
```shell
$ git merge <some_branch>
<git_says_that_a_conflict_occured>
$ git mergetool &
$ git add <paths_to_the_files_with_resolved_conflicts>
$ git commit
```

Show all unpushed commits:
```shell
$ git log --branches --not --remotes
```

Show unpushed tags:
```shell
$ git push --tags --dry-run
```

Show branches sorted by the latest commit date:
```shell
$ git branch --sort=-committerdate
```

Show all commits authored by Konstantin Trushin (and their stats)
siince specific date, ordered by date:
```shell
git log --all --author=Trushin --stat --date-order --since="2021-08-31"
```

Show all commits in compact format sorted by date:
```shell
$ TZ=UTC git log --format="%h %ad %s" --date="format-local:%F %T %Z" master
```

Show committer alongside author:
```shell
$ git log --pretty=fuller master
```

Show commits that have particular text in their diffs:
```shell
$ git log -G 'some?regex' -- path/to/problematic_file
```

Show commits that changed the number of occurrences of a particular text:
```shell
$ git log -S 'some?regex' --pickaxe-regex -- path/to/file
```

Create branch with a systematic name to keep local patches to an upstream repo:
```shell
$ git checkout master
$ ref=$(git describe --tags --long --first-parent | cut -f1,2 -d'-')
$ git checkout -b "$ref-<company_name>-devel" master
```

Examples of `git show`:
```shell
$ git show -s
$ git show <treeish>:<file>
$ git show HEAD~4:index.html
```

Update the date of the last commit (e.g. after squashing):
```shell
$ git commit --amend --no-edit --date=now
$ git commit --amend --no-edit --date="Thu Aug 29 21:55:00 2024 +0400"
```

Export the latest commit in a patch form to be e-mailed to the maintainer
of the upstream repo:
```shell
$ git format-patch -1 HEAD
```

Resolving conflict in submodule commit while rebasing my feature branch on
the `master` branch:
```shell
$ git rebase master my_feature_branch
Applying: <commit message from my_feature_branch>
Using index info to reconstruct a base tree...
M path/to/submodule
Falling back to patching base and 3-way merge...
Failed to merge submodule path/to/submodule (merge following commits not found)
Auto-merging path/to/submodule
CONFLICT (submodule): Merge conflict in path/to/submodule
error: Failed to merge in the changes.
Patch failed at 0001 <commit message from my_feature_branch>
hint: Use 'git am --show-current-patch' to see the failed patch
Resolve all conflicts manually, mark them as resolved with
"git add/rm <conflicted_files>", then run "git rebase --continue".
You can instead skip this commit: run "git rebase --skip".
To abort and get back to the state before "git rebase", run "git rebase --abort".
$ git status -sbu
## HEAD (no branch)
M  file_0.txt
UU path/to/submodule
M  file_1.txt
$
$ git reset my_feature_branch path/to/submodule
$ git status -sbu
## HEAD (no branch)
M  file_0.txt
M  path/to/submodule
M  file_1.txt
$ git status
rebase in progress; onto e7558e9a
You are currently rebasing branch 'iauth1608-remove-yajl' on 'e7558e9a'.
  (all conflicts fixed: run "git rebase --continue")

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
  modified:   file_0.txt
  modified:   path/to/submodule
  modified:   file_1.txt

$ git rebase --continue
Applying: <commit message from my_feature_branch>
Applying: Update subrepo commit
Using index info to reconstruct a base tree...
M path/to/submodule
Falling back to patching base and 3-way merge...
No changes -- Patch already applied.
```
We are all good after that. Check with `git log --all --oneline --grpah`.
