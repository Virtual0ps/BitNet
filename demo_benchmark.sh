#!/bin/bash

################################################################################
# Quick Demo of Benchmark Automation
# This runs a subset of benchmarks to verify the script works
################################################################################

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

STATS_DIR="stats/demo_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${STATS_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Quick Benchmark Demo (< 2 mins)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Output directory: ${STATS_DIR}"
echo ""

# Test 1: Machine info
echo -e "${GREEN}[1/3] Collecting machine info...${NC}"
{
    echo "=== Machine Information ==="
    echo "Architecture: $(uname -m)"
    echo "CPU cores: $(nproc)"
    echo "Timestamp: $(date)"
    echo ""
    lscpu | head -20
} | tee "${STATS_DIR}/machine_info.txt"
echo ""

# Test 2: Quick benchmark test
echo -e "${GREEN}[2/2] Running quick benchmark (single thread, minimal tokens)...${NC}"
if [[ -f "build/bin/llama-bench" ]] && [[ -f "models/BitNet-b1.58-2B-4T/ggml-model-i2_s_embed_q6_k.gguf" ]]; then
    ./build/bin/llama-bench \
        -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s_embed_q6_k.gguf \
        -p 32 -n 32 -t 1 -ngl 0 \
        2>&1 | tee "${STATS_DIR}/bench_quick.txt"
    
    # Parse results
    {
        echo "# Quick Benchmark Results"
        echo ""
        echo "| Threads | Test | Tokens/sec |"
        echo "|---------|------|------------|"
        
        awk -F '|' '
            /bitnet.*pp128/ || /bitnet.*tg128/ {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $7);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $8);
                split($8, perf, "±");
                printf "| %7s | %4s | %10s |\n", $6, $7, perf[1];
            }
        ' "${STATS_DIR}/bench_quick.txt"
    } > "${STATS_DIR}/bench_results.md"
    
    echo ""
    echo -e "${GREEN}Results saved to: ${STATS_DIR}/bench_results.md${NC}"
    cat "${STATS_DIR}/bench_results.md"
else
    echo "Skipping benchmark (model or binary not found)"
fi
echo ""

# Test 3: Quick PPL test (using simplified dataset)
echo -e "${GREEN}[3/3] Running quick PPL test (wiki.simple, 1 embed type)...${NC}"

# Create simplified dataset if needed (first 100 lines for quick demo)
if [[ -f "data/wikitext-2-raw/wiki.test.raw" ]]; then
    echo "Creating simplified dataset (100 lines)..."
    head -100 data/wikitext-2-raw/wiki.test.raw > data/wikitext-2-raw/wiki.simple.raw
fi

if [[ -f "build/bin/llama-perplexity" ]] && [[ -f "data/wikitext-2-raw/wiki.simple.raw" ]]; then
    {
        echo "# Quick PPL Test (Simplified Dataset)"
        echo ""
        echo "| Embed Type | Dataset | PPL |"
        echo "|------------|---------|-----|"
        
        # Test only one embed type with simplified dataset for speed
        embed="q6_k"
        model="models/BitNet-b1.58-2B-4T/ggml-model-i2_s_embed_${embed}.gguf"
        if [[ -f "$model" ]]; then
            echo "Testing: $embed on wiki.simple..."
            output=$(./build/bin/llama-perplexity \
                -m "$model" \
                -f data/wikitext-2-raw/wiki.simple.raw \
                -t 4 -ngl 0 2>&1 || true)
            
            ppl=$(echo "$output" | awk '
                /Final estimate/ && /PPL/ {
                    if (match($0, /PPL[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?)/, m)) {
                        print m[1];
                        exit;
                    }
                }
            ')
            
            if [[ -n "$ppl" ]]; then
                echo "| $embed | wiki.simple | $ppl |"
            else
                echo "| $embed | wiki.simple | N/A |"
            fi
        fi
    } | tee "${STATS_DIR}/ppl_quick.md"
    
    echo ""
    echo -e "${GREEN}Results saved to: ${STATS_DIR}/ppl_quick.md${NC}"
    cat "${STATS_DIR}/ppl_quick.md"
else
    echo "Skipping PPL test (binary or simplified dataset not found)"
    echo "Note: Full PPL test available in: ./run_paper_benchmarks.sh"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Demo completed! (Fast mode - PPL skipped)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "All results in: ${STATS_DIR}/"
echo ""
echo "To run the full automation script:"
echo "  ./run_paper_benchmarks.sh"
echo ""
