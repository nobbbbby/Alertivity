# Maintaining the wiki

## Files

Markdown sources are kept in the app repository’s `wiki/` directory. GitHub stores published wiki pages in a **separate Git repository**, `https://github.com/nobbbbby/Alertivity.wiki.git`. Editing this directory alone does not publish anything. Keep internal development notes in the ignored `docs/` directory out of the public wiki.

These pages were checked against source commit `826cde1` on October 20, 2026, including Free and Pro settings, purchase states, custom Auto Switch priorities, tab help, and the notification timing footer. Home notes the version covered. Recheck it against a verified Store version when preparing a release.

## Page reference

| Topic | Page |
| --- | --- |
| Version note and navigation | Home |
| Build availability and first launch | Getting Started |
| Measurement definitions, system defaults, auto-switch rules | Metrics and Status |
| Configuration paths, allowed values, process limits, duration choices | Settings |
| Alert timing and permissions | Notifications and Permissions |
| Data use, retention, external services, and privacy contact | Privacy Policy |
| Process qualification and actions | Process Insights |
| Troubleshooting and bug reports | Troubleshooting |
| Design rationale and trade-offs | Design Decisions |
| Builds, tests, and source files | Developer Guide |
| Supported languages, string catalogs, translation checks | Localization |

Link to an existing explanation rather than repeating it. Use the app’s labels for configuration paths. Describe what the app does; do not invent product goals or research findings to explain the code.

## Editing

1. Edit the appropriate page in `wiki/` alongside its related code change. Put implementation notes in the Developer Guide.
2. Check behavior in the source and tests, including differences between the two targets. Defaults live in `MonitoringPreferences.swift` and `SettingsStore.swift`; notification timing lives in `NotificationManager.swift`.
3. Keep page filenames stable because GitHub derives page URLs from them. Use the full `https://github.com/nobbbbby/Alertivity/wiki/Page-Name` URL for cross-page links. Update Home and `_Sidebar.md` when adding or renaming pages.
4. Confirm every linked wiki page has a matching Markdown filename, every repository-relative link resolves, and fenced code blocks are balanced. Preview headings, tables, links, sidebar, and footer in GitHub after publishing.
5. Review `git diff --check` and the content diff. Include the work item ID (for this initial setup, AL-76) in any commit or pull request. Documentation-only edits do not require running the app test suite.

## Initial setup

A repository administrator must enable **Wikis** in Settings → General → Features. GitHub requires saving the first page through the web UI before the wiki Git repository can be cloned. Create **Home** if the wiki is empty.

See GitHub’s official [adding or editing wiki pages](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages) and [sidebar/footer guidance](https://docs.github.com/en/communities/documenting-your-project-with-wikis/creating-a-footer-or-sidebar-for-your-wiki).

## Publishing

From the Alertivity checkout, clone the wiki into a temporary directory. Git must be authenticated with push permission:

```sh
wiki_checkout="$(mktemp -d "${TMPDIR:-/tmp}/alertivity-wiki.XXXXXX")"
git clone https://github.com/nobbbbby/Alertivity.wiki.git "$wiki_checkout"
# Continue only if the clone succeeded.
cp wiki/*.md "$wiki_checkout/"
git -C "$wiki_checkout" status --short
git -C "$wiki_checkout" diff --check
git -C "$wiki_checkout" diff
```

Review any existing remote pages before replacing matching names. The copy leaves other pages in place and does not remove deleted pages. Inspect newly added files too, because an unstaged `git diff` does not show untracked content. Then stage only the reviewed page files:

```sh
git -C "$wiki_checkout" add -- \
  Home.md Getting-Started.md Metrics-and-Status.md Settings.md \
  Notifications-and-Permissions.md Process-Insights.md Troubleshooting.md \
  Developer-Guide.md Design-Decisions.md Privacy-Policy.md \
  Maintaining-the-Wiki.md Localization.md _Sidebar.md _Footer.md
git -C "$wiki_checkout" diff --cached --check
git -C "$wiki_checkout" diff --cached
git -C "$wiki_checkout" commit -m 'docs(wiki): Add Alertivity guides (AL-76)'
git -C "$wiki_checkout" push origin HEAD
```

Change the commit message for subsequent updates. If a push is rejected because the remote changed, fetch and review those changes before retrying; do not force-push. Verify the published Home page, sidebar, footer, and links. The README is published separately with the app repository.

If a wiki page was edited directly on GitHub, bring that edit back into `wiki/` before the next publication so it is not overwritten. Use Git history to review or revert mistakes.
