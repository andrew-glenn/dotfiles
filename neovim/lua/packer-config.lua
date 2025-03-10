--[[
______ _             _
| ___ \ |           (_)
| |_/ / |_   _  __ _ _ _ __  ___
|  __/| | | | |/ _` | | '_ \/ __|
| |   | | |_| | (_| | | | | \__ \
\_|   |_|\__,_|\__, |_|_| |_|___/
                __/ |
               |___/
--]]

if package.config:sub(1, 1) == "/" then
	OperatingSystem = "unix"
else
	OperatingSystem = "windows"
end

-- after loading the basic settings, let's check if packer is
-- installed before loading a shitload of errors:
local fn = vim.fn
local install_path

if OperatingSystem == "unix" then
	install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
else
	install_path = fn.stdpath("data") .. "\\site\\pack\\packer\\start\\packer.nvim"
end

if fn.empty(fn.glob(install_path)) > 0 then
	print("Installing packer to: " .. install_path)
	Packer_bootstrap = fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/wbthomason/packer.nvim",
		install_path,
	})
	print("installed packer")
end

vim.cmd([[packadd packer.nvim]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
	return
end

packer.startup(function(use)
	use({ "wbthomason/packer.nvim" })
	-- LSP and code navigation
	-- ------------------------------------
  use({ "neovim/nvim-lspconfig" }) -- Collection of configurations for the built-in LSP client
	use({ "williamboman/nvim-lsp-installer" })
	use({ "hrsh7th/cmp-nvim-lsp" })
	use({ "hrsh7th/cmp-buffer" })
	use({ "hrsh7th/cmp-path" })
	use({ "nvim-lua/popup.nvim" }) -- An implementation of the Popup API from vim in Neovim
	use({ "hrsh7th/cmp-cmdline" })
	use({ "hrsh7th/nvim-cmp" })
	use({ "ray-x/lsp_signature.nvim" })
	use({ "hrsh7th/cmp-nvim-lua" })
	use({ "folke/neodev.nvim" })
  use({ "ray-x/go.nvim"})
  use(
    { 
      "dreamsofcode-io/nvim-dap-go",
      ft = "go", 
      dependencies = "mfussenegger/nvim-dap",
      config = function(_, opts)
        require("dap-go").setup(opts)
      end
    }
    )
  use { "rcarriga/nvim-dap-ui", requires = {"mfussenegger/nvim-dap"} }
  use({"juliosueiras/vim-terraform-completion"})
  use({"hashivim/vim-terraform"})
  use({"vim-syntastic/syntastic"})
  use 'mfussenegger/nvim-dap'
  use({"fatih/vim-go"})
  use({"jodosha/vim-godebug"})
  -- Can't figure out how to make this one work...
	-- use {'jubnzv/virtual-types.nvim', as = "virtual-types"}
	use({ "j-hui/fidget.nvim" })
	use({ "L3MON4D3/LuaSnip" })
	use({ "saadparwaiz1/cmp_luasnip" })
	use({ "stevearc/aerial.nvim" })
	use({ "honza/vim-snippets" })
	use({ "terrortylor/nvim-comment" })
	use({ "jose-elias-alvarez/null-ls.nvim" })
  use({ "hashivim/vim-terraform"})
  use({ "ncm2/ncm2"})
  use({ "oxma/nvim-yarp"})
  use({ "ncm2/ncm2-jedi"})
  use({ "ncm2/ncm2-go"})
  use({'neoclide/coc.nvim', tag = "v0.0.81"})

-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "v2.*", requires = 'kyazdani42/nvim-web-devicons'}
	-- Syntax highlighter
	-- ---------------------
	use({ "romgrk/nvim-treesitter-context" })
  use({'godlygeek/tabular'})
  use({'preservim/vim-markdown'})
  use {"ellisonleao/glow.nvim"}
  use({'juliosueiras/vim-terraform-completion'})

  -- Syntax checkers
  use({"dense-analysis/ale"})
  use({"speshak/vim-cfn"})
  use({"ambv/black"})
  -- Theme / UI
	-- -----------------
  use({"projekt0n/github-nvim-theme"})
  use({"airblade/vim-gitgutter"})
-- use {
--  'lewis6991/gitsigns.nvim',
--  requires = {
--    'nvim-lua/plenary.nvim'
--  },
--  config = function()
--    require('gitsigns').setup()
--  end
  -- tag = 'release' -- To use the latest release
--}
  use({ "rafamadriz/neon", as = "neon" })
  use 'Mofiqul/vscode.nvim'
  use 'feline-nvim/feline.nvim'
  use({'mrjones2014/legendary.nvim'})
	use({
		"catppuccin/nvim",
		as = "catppuccin",
	})
	use({ "rcarriga/nvim-notify" })
	use({ "norcalli/nvim-colorizer.lua" })
	use({
		"akinsho/bufferline.nvim",
		requires = "kyazdani42/nvim-web-devicons",
	})
	use({
		"kyazdani42/nvim-tree.lua",
		requires = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icon
		},
	})
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "kyazdani42/nvim-web-devicons", opt = true },
	})
	use({
		"goolord/alpha-nvim",
		requires = { "kyazdani42/nvim-web-devicons" },
	})
	use({ "lukas-reineke/indent-blankline.nvim" })
	use({ "stevearc/dressing.nvim" })


	-- Search tools
	-- --------------
	use({ "nvim-lua/plenary.nvim" })
	use({ "junegunn/fzf" })
	use({ "junegunn/fzf.vim" })
	use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
	use({ "ibhagwan/fzf-lua", requires = { "kyazdani42/nvim-web-devicons" } })
	use({
		"nvim-telescope/telescope.nvim",
		requires = { { "nvim-lua/plenary.nvim" } },
	})

	use({ "windwp/nvim-autopairs" })
	use({ "ahmedkhalf/project.nvim" })
	use({ "Shatur/neovim-session-manager" })

	if Packer_bootstrap then
		print("running sync")
		require("packer").sync()
	end
end)

