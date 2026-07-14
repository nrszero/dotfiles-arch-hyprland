return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end
    },
    {
        "williamboman/mason-lspconfig.nvim",
	    config = function()
	        require("mason-lspconfig").setup({
		        ensure_installed = {"lua_ls", "pyright", "omnisharp"},
	        })
	    end
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp", 
        },
        config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
            -- Apply completion capabilities globally to ALL language servers
            vim.lsp.config('*', {
                capabilities = capabilities
            })
            
            local omnisharp_path = vim.fn.stdpath("data") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll"
            -- This is required because OmniSharp needs to know where its DLL is
            vim.lsp.config('omnisharp', {
                cmd = { "dotnet", omnisharp_path },
                capabilities = capabilities,
                settings = {
                    FormattingOptions = {
                        EnableEditorConfigSupport = true,
                    },
                    RoslynExtensionsOptions = {
                        -- Required for Unity project analysis
                        EnableDecompilationSupport = true,
                        EnableImportCompletion = true,
                        EnableAnalyzersSupport = true,
                    },
                },
            })
            vim.lsp.config("qml-language-server", {
              cmd = { "qml-language-server" },
              filetypes = { "qml" },
              root_markers = { { "qmldir", "shell.qml" }, ".git" },
            })
            vim.lsp.enable("qml-language-server")
            vim.lsp.enable('lua_ls')
	        vim.lsp.enable('pyright')
            vim.lsp.enable('omnisharp')
	    end
    }
}
