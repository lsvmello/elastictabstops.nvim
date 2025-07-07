# Elastic Tabstops for Neovim

This is a ~hack~ implementation of [Elastic Tabstops](https://nickgravgaard.com/elastic-tabstops) for Neovim.

How it works:
1. There is no way to get the "rendered line" and Neovim adds a different spacing for tabs, then I took advantage of setting tab's listchars (see `h: lcs-tab`) as _nil_ so Neovim always render it as `^I`.
1. Then this plugin hides the `^I` with an overlay _extmark_ and then add the dynamic spacing using an inline _extmark_.
1. The _extmarks_ of the whole buffer are build once the plugin is activated and on every change the paragraph's _extmarks_ are re-build.

Check `:help api-extended-marks` for more information about _extmarks_

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
 "lsvmello/elastictabstops.nvim",
 cmds = "ElasticTabstops",
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
 "lsvmello/elastictabstops.nvim",
}
```

_There is no need to call `require("elastictabstops").setup()`_

## Usage

Execute `:ElasticTabstops` to toggle elastic tabstops on current buffer or explicitly call `:ElasticTabstops enable` or `:ElasticTabstops disable`.
