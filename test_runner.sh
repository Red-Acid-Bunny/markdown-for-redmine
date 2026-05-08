#!/usr/bin/env bash
#
# test_runner.sh — автоматическая проверка конвертации MD → Textile
#
# Использование:
#   ./test_runner.sh                # запустить все тесты
#   ./test_runner.sh 20 21 22       # запустить только указанные
#   ./test_runner.sh --update       # обновить эталонные файлы (после fixes)
#   ./test_runner.sh --verbose      # показать содержимое при FAIL
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="$SCRIPT_DIR/redmine_textile.lua"
TESTS_DIR="$SCRIPT_DIR/tests"
EXPECTED_DIR="$SCRIPT_DIR/expected"
ACTUAL_DIR="$SCRIPT_DIR/actual"
PASS_COUNT=0
FAIL_COUNT=0
FAIL_LIST=()
VERBOSE=false

# --- Аргументы ---
if [[ "${1:-}" == "--update" ]]; then
    echo "Обновление эталонных файлов..."
    mkdir -p "$EXPECTED_DIR"
    for f in "$TESTS_DIR"/*.md; do
        name=$(basename "$f" .md)
        pandoc --lua-filter="$FILTER" -f markdown -t textile "$f" \
            -o "$EXPECTED_DIR/${name}.textile" 2>&1
        echo "  updated: $name"
    done
    echo "Готово."
    exit 0
fi

if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
    shift
fi

# --- Собираем список тестов ---
if [[ $# -gt 0 ]]; then
    TESTS=()
    for arg in "$@"; do
        # ищем по номеру или по имени
        found=false
        for f in "$TESTS_DIR"/*.md; do
            name=$(basename "$f" .md)
            if [[ "$name" == *"$arg"* ]]; then
                TESTS+=("$name")
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            echo "Тест не найден: $arg" >&2
            exit 1
        fi
    done
else
    TESTS=()
    for f in "$TESTS_DIR"/*.md; do
        TESTS+=("$(basename "$f" .md)")
    done
fi

# --- Прогон ---
mkdir -p "$ACTUAL_DIR"

for name in "${TESTS[@]}"; do
    src="$TESTS_DIR/${name}.md"
    expected="$EXPECTED_DIR/${name}.textile"
    actual="$ACTUAL_DIR/${name}.textile"

    # конвертируем
    if ! pandoc --lua-filter="$FILTER" -f markdown -t textile "$src" \
        -o "$actual" 2>/dev/null; then
        echo "FAIL: $name  (ошибка конвертации)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST+=("$name")
        continue
    fi

    # эталон существует?
    if [[ ! -f "$expected" ]]; then
        echo "MISS: $name  (нет эталона — запусти с --update)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST+=("$name")
        continue
    fi

    # сравниваем
    if diff -u "$expected" "$actual" > /tmp/diff_out.txt 2>/dev/null; then
        echo "PASS: $name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $name"
        if $VERBOSE; then
            cat /tmp/diff_out.txt
            echo ""
        fi
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST+=("$name")
    fi
done

# --- Итог ---
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "=============================="
echo "  PASS: $PASS_COUNT / $TOTAL"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "  FAIL: $FAIL_COUNT — ${FAIL_LIST[*]}"
    echo ""
    echo "Сравнение:"
    echo "  diff expected/<name>.textile actual/<name>.textile"
fi
echo "=============================="

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
