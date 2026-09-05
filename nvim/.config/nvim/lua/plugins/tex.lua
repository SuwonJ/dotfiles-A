-- ~/.config/nvim/lua/plugins/tex.lua
return {
  {
    "lervag/vimtex",
    lazy = false, -- Vimtex 공식 권장: Tex 파일 열릴 때 올바른 로딩을 위해 lazy=false 권장
    init = function()
      -- 1. 컴파일러 설정: latexmk가 있으면 사용, 없으면 lualatex로 폴백
      if vim.fn.executable("latexmk") == 1 then
        vim.g.vimtex_compiler_method = "latexmk"
        vim.g.vimtex_compiler_latexmk = {
          options = {
            "-shell-escape",
            "-verbose",
            "-file-line-error",
            "-synctex=1",
            "-interaction=nonstopmode",
          },
        }
        vim.g.vimtex_compiler_latexmk_engines = {
          _ = "-lualatex",
        }
      else
        vim.g.vimtex_compiler_method = "generic"
        vim.g.vimtex_compiler_generic = {
          command = "lualatex -shell-escape -file-line-error -synctex=1 -interaction=nonstopmode @tex",
        }
      end

      -- 2. PDF 뷰어 설정
      if vim.fn.executable("zathura") == 1 then
        vim.g.vimtex_view_method = "zathura"
      else
        vim.g.vimtex_view_method = "general"
      end

      -- 3. 컴파일 중 생기는 임시 찌꺼기 파일들(.aux, .log 등) 자동 청소 설정
      vim.g.vimtex_clean_enabled = 1
      vim.g.vimtex_quickfix_mode = 0 -- 에러창이 매번 강제로 튀어나오는 것 방지
    end,
  },
}
