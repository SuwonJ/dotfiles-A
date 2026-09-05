-- ~/.config/nvim/lua/plugins/runner.lua

-- LazyVim의 설정을 덮어쓰지 않고, 그냥 설정(config) 폴더 로드 시점에 단축키와 실행 함수만 독립적으로 등록합니다.
local function run_code()
  vim.cmd("write") -- 실행 전 현재 파일 자동 저장
  local file_path = vim.fn.expand("%:p")
  local file_dir = vim.fn.expand("%:p:h")
  local file_name = vim.fn.expand("%:t")
  local file_ext = vim.fn.expand("%:e")
  local name_without_ext = vim.fn.expand("%:t:r")

  local cmd = ""

  if file_ext == "py" then
    cmd = string.format("python3 -u %s", file_name)
  elseif file_ext == "cpp" then
    cmd = string.format("g++ -O2 %s -o %s && ./%s", file_name, name_without_ext, name_without_ext)
  else
    print("지원하지 않는 파일 형식입니다: " .. file_ext)
    return
  end

  -- 아래쪽에 높이 15짜리 수평 터미널 스플릿 열고 명령 실행
  vim.cmd("botright 15new | terminal cd " .. file_dir .. " && " .. cmd)
  vim.cmd("startinsert") -- 터미널 실행 직후 자동으로 포커스 및 입력 대기 상태로 진입
end

-- F5 키에 내장 러너 바인딩
vim.keymap.set("n", "<F5>", run_code, { desc = "Run Python/C++ code directly", silent = true })

-- 아무 플러그인 스펙도 반환하지 않음 (LazyVim 설정을 방해하지 않음)
return {}
