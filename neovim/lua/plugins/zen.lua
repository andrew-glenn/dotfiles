return {
  { "folke/twilight.nvim", cmd = "Twilight" },
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    ft = "markdown",
    opts = { plugins = { twilight = { enabled = true } } },
  },
}
