---
author: Lombardi Costantino
creation date: <% tp.file.creation_date() %>
description: First blog post for my personal CS Blog
---
Something to show in new Hugo blog posts.
▶ rsync -av --delete "/Users/lcs-dev/Documents/Obsidian-Vault/XSPC-Vault/Blog/Posts" "/Users/lcs-dev/04_LCS.Blog/CS-Topics/content/posts"


!![Image Description](/images/Screenshot%202024-12-16%20at%2014.08.17.png)

Failed loading config.keymaps

/Users/lcs-dev/.config/nvim/lua/config/keymaps.lua:8: module 'telescope.builtin' not found:
	no field package.preload['telescope.builtin']
cache_loader: module telescope.builtin not found
cache_loader_lib: module telescope.builtin not found
	no file './telescope/builtin.lua'
	no file '/opt/homebrew/share/luajit-2.1/telescope/builtin.lua'
	no file '/usr/local/share/lua/5.1/telescope/builtin.lua'
	no file '/usr/local/share/lua/5.1/telescope/builtin/init.lua'
	no file '/opt/homebrew/share/lua/5.1/telescope/builtin.lua'
	no file '/opt/homebrew/share/lua/5.1/telescope/builtin/init.lua'
	no file './telescope/builtin.so'
	no file '/usr/local/lib/lua/5.1/telescope/builtin.so'
	no file '/opt/homebrew/lib/lua/5.1/telescope/builtin.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'
	no file './telescope.so'
	no file '/usr/local/lib/lua/5.1/telescope.so'
	no file '/opt/homebrew/lib/lua/5.1/telescope.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'

# stacktrace:
  - ~/.config/nvim/lua/config/keymaps.lua:8
  - /LazyVim/lua/lazyvim/config/init.lua:252
  - /LazyVim/lua/lazyvim/config/init.lua:251 _in_ **_load**
  - /LazyVim/lua/lazyvim/config/init.lua:262 _in_ **load**
  - /LazyVim/lua/lazyvim/config/init.lua:185
