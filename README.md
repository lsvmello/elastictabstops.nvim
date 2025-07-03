# Elastic Tabstops for Neovim

This is a hack implementation of [Elastic Tabstops](https://nickgravgaard.com/elastic-tabstops) for Neovim.

It's a hack because:
1. I couldn't find a way to get the "rendered line" and Neovim adds a different spacing for tabs. Then I took advantage of setting tab's listchars (see `h: lcs-tab`) as _nil_ then Neovim always render it as `^I`.
1. Then this plugin hides the `^I` with an overlay _extmark_ and then add the dynamic spacing using an inline _extmark_.
1. The _extmarks_ are build on every change. I might improve this later if needed.

Check `:help api-extended-marks` for more information about _extmarks_

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
 "lsvmello/elastictabstops.nvim",
 cmds = { "ElasticTabstopsEnable", "ElasticTabstopsDisable" },
 opts = {},
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
 "lsvmello/elastictabstops.nvim",
 config = function() require('elastictabstops').setup() end
}
```

## Usage

Execute `:ElasticTabstopsEnable` to enable elastic tabstops on the current buffer.

Execute `:ElasticTabstopsDisable` to disable elastic tabstops on the current buffer.
