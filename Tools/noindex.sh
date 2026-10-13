# 빌드 결과 폴더를 Spotlight가 보지 않게 한다. 다른 스크립트가 source로 불러 쓴다.
#
#   source Tools/noindex.sh; daylog_noindex_dir build
#
# 빌드 폴더 안의 Daylog.app(아카이브, 공증본, 되돌리기용 사본, 검증 빌드)은 모두 진짜 앱 묶음이라, Spotlight가 색인하면
# macOS의 저장 공간 목록과 검색 결과에 "Daylog"가 버전별로 여러 개 나온다. 이름이 `.noindex`로 끝나는 폴더는 색인하지 않으므로,
# 실제 폴더는 `<이름>.noindex`에 두고 원래 이름은 그 폴더를 가리키는 링크로 남긴다. 스크립트와 문서의 경로는 그대로 쓸 수 있다.
# 폴더를 옮길 뿐 안의 파일은 지우거나 바꾸지 않는다.
daylog_noindex_dir() {
  local name="$1" real="$1.noindex"
  if [[ -L "$name" ]]; then
    [[ -d "$real" ]] || mkdir -p "$real"
    return 0
  fi
  if [[ -e "$name" ]]; then
    if [[ -e "$real" ]]; then
      echo "주의: $name 과 $real 이 둘 다 있습니다. $name 은 그대로 둡니다(Spotlight에 계속 보입니다)." >&2
      return 0
    fi
    mv "$name" "$real"
  else
    mkdir -p "$real"
  fi
  ln -s "$real" "$name"
}
