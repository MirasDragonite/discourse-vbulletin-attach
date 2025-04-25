# 📎 Discourse JSON Attachment Parser Plugin

A lightweight Discourse plugin that automatically parses `[ATTACH=JSON]{...}[/ATTACH]` tags in posts and converts them into valid HTML `<img>` elements.

## 🔧 Features

- Detects `[ATTACH=JSON]{...}[/ATTACH]` tags within post content.
- Extracts JSON attributes and renders them as `<img>` tags.
- Automatically fixes typographic quotes to avoid JSON parsing errors.
- Works both on post creation and post editing.

## 📌 Example

### Original post content:

GoBrowser not only hides your identity...

[ATTACH=JSON]{“alt”:“Screenshot”,“data-attachmentid”:“267729”,“width”:“431”,“height”:“232”}[/ATTACH]

### After processing:

```html
GoBrowser not only hides your identity...

<img src="/uploads/default/original/267729" alt="Screenshot" width="431" height="232" />
```
## 🛠 Installation
Clone the plugin into your Discourse plugins directory:

```
cd /var/www/discourse/plugins
git clone https://github.com/MirasDragonite/discourse-vbulletin-attach.git
```
 Rebuild or restart the Discourse container:

### 🧠 How It Works
The plugin hooks into on(:post_process_cooked) to modify the cooked HTML content.

It replaces smart quotes (“”) with standard double quotes (") to make the JSON parsable.

It parses the JSON and generates an <img> tag with the appropriate attributes (e.g., src, alt, width, height).

If the data-attachmentid is present, it constructs the image src as /uploads/default/original/{id}.

### ⚠️ Notes
Make sure your JSON is valid and uses proper quotes (or let the plugin fix them).

If parsing fails, a visible [ATTACH parse error: ...] message will appear in the post.

### ✅ Requirements
```
Discourse v2.7 or later

Ruby 2.7+

Plugin assumes attachment IDs are valid Discourse upload IDs
```
