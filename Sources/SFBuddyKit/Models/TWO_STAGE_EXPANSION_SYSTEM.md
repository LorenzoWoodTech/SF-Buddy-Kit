# Two-Stage Symbol Expansion System

## Overview

The Two-Stage Expansion System is an advanced recommendation engine for SF Symbols that provides more comprehensive and diverse symbol suggestions by leveraging semantic expansion.

## How It Works

### Stage 1: Synonym Expansion
1. **Input**: User's search term (e.g., "home")
2. **AI Processing**: Generate 20-30 synonyms and related concepts
   - Direct synonyms (house, dwelling, residence)
   - Related concepts (family, shelter, comfort)
   - Visual metaphors (nest, haven, sanctuary)
   - Actions (live, dwell, reside)
   - Associated objects (door, roof, fireplace)
3. **Direct Validation**: Check if any synonyms are valid SF Symbol names
   - Example: "house" → validates as `house` symbol
   - Normalized: lowercase, no spaces
4. **Output**: `SynonymExpansionResult` with:
   - Original term
   - List of synonyms/concepts
   - Directly renderable symbols

### Stage 2: Symbol Mapping
1. **Input**: All concepts (original + synonyms)
2. **AI Processing**: Ask AI to suggest SF Symbol names for ALL concepts
   - Prompt includes all expanded terms
   - AI has more semantic context
   - Results in more diverse symbol suggestions
3. **Validation**: Check each suggested symbol against SF Symbols library
4. **Deduplication**: Remove duplicates between direct renders and mapped symbols
5. **Output**: `SymbolMappingResult` with:
   - Valid symbols
   - Invalid symbol names (for debugging)

### Result Combination
- Start with mapped symbols from Stage 2
- Add direct renderable symbols from Stage 1 (if not already included)
- Final list prioritizes AI-mapped symbols but includes direct matches

## Example Flow

### Input
User searches for: **"music"**

### Stage 1 Output
**Synonyms Generated:**
- melody, tune, harmony, rhythm, sound, audio, song, composition, performance, instrument, note, beat, tempo, symphony, orchestra, playlist, track, recording, concert, band

**Direct Renders Found:**
- None (no exact matches)

### Stage 2 Input
**Concepts to Map:**
- music, melody, tune, harmony, rhythm, sound, audio, song, composition, performance, instrument, note, beat, tempo, symphony, orchestra, playlist, track, recording, concert, band

### Stage 2 Output
**Symbols Mapped:**
- `music.note`
- `music.quarternote.3`
- `music.note.list`
- `hifispeaker.fill`
- `waveform`
- `headphones`
- `guitar`
- `pianokeys`
- `mic.fill`
- `play.circle.fill`
- `radio.fill`
- `music.mic`

### Final Result
12 diverse, semantically-related symbols representing music and related concepts.

## Benefits

### 1. **Semantic Expansion**
- Discovers symbols related to concepts, not just literal matches
- Finds metaphorical and associated symbols

### 2. **Higher Coverage**
- Two chances to find symbols: direct synonym matching + AI mapping
- Broader semantic field exploration

### 3. **Better Context**
- AI receives multiple related concepts for richer context
- Results in more creative and relevant suggestions

### 4. **Quality Validation**
- All symbols validated against SF Symbols library
- Invalid suggestions filtered out
- Direct renders ensure exact matches are included

## Configuration

### Enable/Disable