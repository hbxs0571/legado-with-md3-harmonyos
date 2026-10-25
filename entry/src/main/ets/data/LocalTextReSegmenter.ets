/** 按 Android ContentHelp.reSegment 的本地规则重排章节段落。 */
export class LocalTextReSegmenter {
  private static readonly MARK_SENTENCES_END: string = '？。！?!~';
  private static readonly MARK_SENTENCES_END_P: string = '.？。！?!~';
  private static readonly MARK_SENTENCES_MID: string = '.，、,—…';
  private static readonly MARK_SENTENCES_SAY: string = '问说喊唱叫骂道着答';
  private static readonly MARK_QUOTATION_BEFORE: string = '，：,:';
  private static readonly MARK_QUOTATION: string = `"“”'`;
  private static readonly MARK_QUOTATION_RIGHT: string = `"”`;
  private static readonly WORD_MAX_LENGTH: number = 16;
  private static readonly punctuationPattern: RegExp = new RegExp('^\\p{P}$', 'u');

  static reSegment(content: string, chapterName: string): string {
    if (content.length === 0) { return content; }
    const dict = LocalTextReSegmenter.makeDict(content);
    let paragraphs = LocalTextReSegmenter.splitWithoutTrailingEmpty(content
      .replace(/&quot;/g, '“')
      .replace(/[:：]['"‘”“]+/g, '：“')
      .replace(/["”“]+\s*["”“][\s"”“]*/g, '”\n“'), /\n\s*/g);
    let buffer: string = '  ';
    const firstParagraph = paragraphs[0] ?? '';
    if (LocalTextReSegmenter.trimControl(firstParagraph) !== LocalTextReSegmenter.trimControl(chapterName)) {
      buffer += firstParagraph.replace(/[\u3000\s]+/g, '');
    }

    for (let index = 1; index < paragraphs.length; index++) {
      const last = buffer.charAt(buffer.length - 1);
      const previous = buffer.charAt(buffer.length - 2);
      if (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_SENTENCES_END, last) ||
        (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION_RIGHT, last) &&
          LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_SENTENCES_END, previous))) {
        buffer += '\n';
      }
      buffer += (paragraphs[index] ?? '').replace(/[\u3000\s]/g, '');
    }

    paragraphs = LocalTextReSegmenter.splitWithoutTrailingEmpty(buffer
      .replace(/["”“]+\s*["”“]+/g, '”\n“')
      .replace(/["”“]+(？。！?!~)["”“]+/g, '”$1\n“')
      .replace(/["”“]+(？。！?!~)([^"”“])/g, '”$1\n$2')
      .replace(/([问说喊唱叫骂道着答])[\.。]/g, '$1。\n'), /\n/g);

    let segmented: string = '';
    for (let index = 0; index < paragraphs.length; index++) {
      segmented += '\n' + LocalTextReSegmenter.findNewLines(paragraphs[index] ?? '', dict);
    }
    segmented = LocalTextReSegmenter.reduceLength(segmented);
    return segmented
      .replace(/^\s+/, '')
      .replace(/\s*["”“]+\s*["”“][\s"”“]*/g, '”\n“')
      .replace(/[:：][”“"\s]+/g, '：“')
      .replace(/\n(\s*)/g, '\n');
  }

  private static reduceLength(content: string): string {
    const paragraphs = LocalTextReSegmenter.splitWithoutTrailingEmpty(content, /\n/g);
    const isDialogue: boolean[] = [];
    for (let index = 0; index < paragraphs.length; index++) {
      isDialogue.push(/^["”“][^"”“]+["”“]$/.test(paragraphs[index] ?? ''));
    }
    let dialogue: number = 0;
    for (let index = 0; index < paragraphs.length; index++) {
      if (isDialogue[index] === true) {
        if (dialogue < 0) { dialogue = 1; }
        else if (dialogue < 2) { dialogue++; }
      } else if (dialogue > 1) {
        paragraphs[index] = LocalTextReSegmenter.splitQuote(paragraphs[index] ?? '');
        dialogue--;
      } else if (dialogue > 0 && index < paragraphs.length - 2 && isDialogue[index + 1] === true) {
        paragraphs[index] = LocalTextReSegmenter.splitQuote(paragraphs[index] ?? '');
      }
    }
    return '\n' + paragraphs.join('\n');
  }

  private static splitQuote(content: string): string {
    const length = content.length;
    if (length < 3) { return content; }
    if (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION, content.charAt(0))) {
      const index = LocalTextReSegmenter.seekIndex(content, LocalTextReSegmenter.MARK_QUOTATION, 1, length - 2, true) + 1;
      if (index > 1 && !LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION_BEFORE, content.charAt(index - 1))) {
        return content.substring(0, index) + '\n' + content.substring(index);
      }
    } else if (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION, content.charAt(length - 1))) {
      const index = length - 1 - LocalTextReSegmenter.seekIndex(content, LocalTextReSegmenter.MARK_QUOTATION, 1, length - 2, false);
      if (index > 1 && !LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION_BEFORE, content.charAt(index - 1))) {
        return content.substring(0, index) + '\n' + content.substring(index);
      }
    }
    return content;
  }

  private static forceSplit(content: string, offset: number, minimum: number, gain: number, trigger: number): number[] {
    const result: number[] = [];
    const sentenceEnds = LocalTextReSegmenter.seekIndexes(content,
      LocalTextReSegmenter.MARK_SENTENCES_END_P, 0, content.length - 2, true);
    const sentenceMids = LocalTextReSegmenter.seekIndexes(content,
      LocalTextReSegmenter.MARK_SENTENCES_MID, 0, content.length - 2, true);
    if (sentenceEnds.length < trigger && sentenceMids.length < trigger * 3) { return result; }
    let midIndex: number = 0;
    let sentenceIndex: number = minimum;
    while (sentenceIndex < sentenceEnds.length) {
      let midCount: number = 0;
      while (midIndex < sentenceMids.length) {
        if ((sentenceMids[midIndex] ?? 0) < (sentenceEnds[sentenceIndex] ?? 0)) { midCount++; }
        midIndex++;
      }
      if (Math.random() * gain < 0.8 + midCount / 2.5) {
        result.push((sentenceEnds[sentenceIndex] ?? 0) + offset);
        sentenceIndex = Math.max(sentenceIndex + minimum, sentenceIndex);
      }
      sentenceIndex++;
    }
    return result;
  }

  private static findNewLines(content: string, dict: string[]): string {
    const chars: string[] = content.split('');
    const quotePositions: number[] = [];
    let insertNewLines: number[] = [];
    const modes: number[] = [];
    for (let index = 0; index < content.length; index++) { modes.push(0); }
    let waitClose: boolean = false;

    for (let index = 0; index < content.length; index++) {
      const character = content.charAt(index);
      if (!LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION, character)) { continue; }
      const size = quotePositions.length;
      if (size > 0) {
        const previousQuote = quotePositions[size - 1] ?? 0;
        if (index - previousQuote === 2) {
          let remove: boolean = false;
          if (waitClose) {
            remove = LocalTextReSegmenter.matches(',，、/', content.charAt(index - 1));
          } else {
            remove = LocalTextReSegmenter.matches(',，、/和与或', content.charAt(index - 1));
          }
          if (remove) {
            chars[index] = '“';
            chars[index - 2] = '”';
            quotePositions.pop();
            modes[size - 1] = 1;
            modes[size] = -1;
            continue;
          }
        }
      }
      quotePositions.push(index);
      if (index > 1) {
        const before = content.charAt(index - 1);
        let priorBefore: string = '';
        if (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_QUOTATION_BEFORE, before)) {
          if (quotePositions.length > 1) {
            const lastQuote = quotePositions[quotePositions.length - 2] ?? 0;
            let previousPosition: number = 0;
            if (before === ',' || before === '，') {
              if (quotePositions.length > 2) {
                previousPosition = quotePositions[quotePositions.length - 3] ?? 0;
                if (previousPosition > 0) { priorBefore = content.charAt(previousPosition - 1); }
              }
            }
            if (LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_SENTENCES_END_P, priorBefore)) {
              insertNewLines.push(previousPosition - 1);
            } else if (!LocalTextReSegmenter.matches('的', priorBefore)) {
              const lastEnd = LocalTextReSegmenter.seekLast(content,
                LocalTextReSegmenter.MARK_SENTENCES_END, index, lastQuote);
              insertNewLines.push(lastEnd > 0 ? lastEnd : lastQuote);
            }
          }
          waitClose = true;
          modes[size] = 1;
          if (size > 0) {
            modes[size - 1] = -1;
            if (size > 1) { modes[size - 2] = 1; }
          }
        } else if (waitClose) {
          waitClose = false;
          insertNewLines.push(index);
        }
      }
    }

    const quoteCount = quotePositions.length;
    let opened: boolean = false;
    if (quoteCount > 0) {
      for (let index = 0; index < quoteCount; index++) {
        if ((modes[index] ?? 0) > 0) {
          opened = true;
        } else if ((modes[index] ?? 0) < 0) {
          if (!opened && index > 0) { modes[index] = 3; }
          opened = false;
        } else {
          opened = !opened;
          modes[index] = opened ? 2 : -2;
        }
      }
      if (opened) {
        const lastPosition = quotePositions[quoteCount - 1] ?? 0;
        if (lastPosition - chars.length > -3) {
          if (quoteCount > 1) { modes[quoteCount - 2] = 4; }
          modes[quoteCount - 1] = -4;
        } else if (!LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_SENTENCES_SAY,
          chars[chars.length - 2] ?? '')) {
          chars.push('”');
        }
      }

      let previousMode: number = -1;
      let index: number = 0;
      let priorPosition = (quotePositions[0] ?? 0) - 1;
      if (priorPosition < 0) {
        index = 1;
        previousMode = 0;
      }
      while (index < quoteCount) {
        priorPosition = (quotePositions[index] ?? 0) - 1;
        const currentMode = modes[index] ?? 0;
        if (previousMode < 0 && currentMode > 0 &&
          LocalTextReSegmenter.matches(LocalTextReSegmenter.MARK_SENTENCES_END, chars[priorPosition] ?? '')) {
          insertNewLines.push(priorPosition);
        }
        previousMode = currentMode;
        index++;
      }
    }

    const verifiedNewLines: number[] = [];
    for (let index = 0; index < insertNewLines.length; index++) {
      const position = insertNewLines[index] ?? -1;
      if (LocalTextReSegmenter.matches(`"'”“`, chars[position] ?? '')) {
        const start = LocalTextReSegmenter.seekLast(content, `"'”“`, position - 1,
          position - LocalTextReSegmenter.WORD_MAX_LENGTH);
        if (start > 0) {
          const word = content.substring(start + 1, position);
          if (dict.indexOf(word) >= 0 ||
            LocalTextReSegmenter.matches('的地得', content.charAt(start))) {
            continue;
          }
        }
      }
      verifiedNewLines.push(position);
    }
    insertNewLines = LocalTextReSegmenter.uniqueSorted(verifiedNewLines);

    let insertionIndex: number = 0;
    let splitProgress: number = 0;
    let nextLine: number = insertNewLines.length > 0 ? insertNewLines[0] ?? -1 : -1;
    let gain: number = 3;
    let minimum: number = 0;
    let trigger: number = 2;
    for (let index = 0; index < quotePositions.length; index++) {
      const quotePosition = quotePositions[index] ?? 0;
      if (quotePosition > 0) {
        gain = 4;
        minimum = 2;
        trigger = 4;
      } else {
        gain = 3;
        minimum = 0;
        trigger = 2;
      }
      while (insertionIndex < insertNewLines.length) {
        if (nextLine >= quotePosition) { break; }
        nextLine = insertNewLines[insertionIndex] ?? -1;
        if (splitProgress < nextLine) {
          const part = chars.slice(splitProgress, nextLine).join('');
          insertNewLines.push(...LocalTextReSegmenter.forceSplit(part, splitProgress, minimum, gain, trigger));
          splitProgress = nextLine + 1;
        }
        insertionIndex++;
      }
      if (splitProgress < quotePosition) {
        const part = chars.slice(splitProgress, quotePosition + 1).join('');
        insertNewLines.push(...LocalTextReSegmenter.forceSplit(part, splitProgress, minimum, gain, trigger));
        splitProgress = quotePosition + 1;
      }
    }
    while (insertionIndex < insertNewLines.length) {
      nextLine = insertNewLines[insertionIndex] ?? -1;
      if (splitProgress < nextLine) {
        const part = chars.slice(splitProgress, nextLine).join('');
        insertNewLines.push(...LocalTextReSegmenter.forceSplit(part, splitProgress, minimum, gain, trigger));
        splitProgress = nextLine + 1;
      }
      insertionIndex++;
    }
    if (splitProgress < chars.length) {
      const part = chars.slice(splitProgress).join('');
      insertNewLines.push(...LocalTextReSegmenter.forceSplit(part, splitProgress, minimum, gain, trigger));
    }

    const insertQuote: boolean[] = [];
    opened = false;
    for (let index = 0; index < quoteCount; index++) {
      const position = quotePositions[index] ?? 0;
      insertQuote.push(false);
      if ((modes[index] ?? 0) > 0) {
        chars[position] = '“';
        if (opened) { insertQuote[index] = true; }
        opened = true;
      } else if ((modes[index] ?? 0) < 0) {
        chars[position] = '”';
        opened = false;
      } else {
        opened = !opened;
        chars[position] = opened ? '“' : '”';
      }
    }
    insertNewLines = LocalTextReSegmenter.uniqueSorted(insertNewLines);
    let output: string = '';
    let lineIndex: number = 0;
    let progress: number = 0;
    nextLine = insertNewLines.length > 0 ? insertNewLines[0] ?? -1 : -1;
    for (let index = 0; index < quotePositions.length; index++) {
      const quotePosition = quotePositions[index] ?? 0;
      while (lineIndex < insertNewLines.length) {
        if (nextLine >= quotePosition) { break; }
        nextLine = insertNewLines[lineIndex] ?? -1;
        output += chars.slice(progress, nextLine + 1).join('') + '\n';
        progress = nextLine + 1;
        lineIndex++;
      }
      if (progress < quotePosition) {
        output += chars.slice(progress, quotePosition + 1).join('');
        progress = quotePosition + 1;
      }
      if (insertQuote[index] === true && output.length > 2) {
        if (output.charAt(output.length - 1) === '\n') { output += '“'; }
        else { output = output.substring(0, output.length - 1) + '”\n' + output.charAt(output.length - 1); }
      }
    }
    while (lineIndex < insertNewLines.length) {
      nextLine = insertNewLines[lineIndex] ?? -1;
      if (progress <= nextLine) {
        output += chars.slice(progress, nextLine + 1).join('') + '\n';
        progress = nextLine + 1;
      }
      lineIndex++;
    }
    if (progress < chars.length) { output += chars.slice(progress).join(''); }
    return output;
  }

  private static makeDict(content: string): string[] {
    const words: string[] = [];
    const seen: string[] = [];
    let index: number = 0;
    while (index < content.length) {
      if (!LocalTextReSegmenter.matches(`"'”“`, content.charAt(index))) { index++; continue; }
      let end: number = index + 1;
      while (end < content.length && end - index <= LocalTextReSegmenter.WORD_MAX_LENGTH &&
        content.charAt(end) !== '\n' && !LocalTextReSegmenter.punctuationPattern.test(content.charAt(end))) {
        end++;
      }
      if (end - index - 1 >= 1 && end - index - 1 <= LocalTextReSegmenter.WORD_MAX_LENGTH &&
        LocalTextReSegmenter.matches(`"'”“`, content.charAt(end))) {
        const word = content.substring(index + 1, end);
        if (seen.indexOf(word) >= 0 && words.indexOf(word) < 0) { words.push(word); }
        else if (seen.indexOf(word) < 0) { seen.push(word); }
      }
      index++;
    }
    return words;
  }

  private static seekIndexes(content: string, key: string, from: number, to: number, inOrder: boolean): number[] {
    const result: number[] = [];
    if (content.length - from < 1) { return result; }
    let index: number = from > 0 ? from : 0;
    const end: number = to > 0 ? Math.min(content.length, to) : content.length;
    while (index < end) {
      const character = inOrder ? content.charAt(index) : content.charAt(content.length - index - 1);
      if (key.indexOf(character) >= 0) {
        if (result.length > 0 && index - (result[result.length - 1] ?? 0) === 1) {
          result[result.length - 1] = index;
        } else { result.push(index); }
      }
      index++;
    }
    return result;
  }

  private static seekLast(content: string, key: string, from: number, to: number): number {
    if (content.length - from < 1) { return -1; }
    let index: number = content.length - 1;
    if (from < index && index > 0) { index = from; }
    const end: number = to > 0 ? to : 0;
    while (index > end) {
      if (key.indexOf(content.charAt(index)) >= 0) { return index; }
      index--;
    }
    return -1;
  }

  private static seekIndex(content: string, key: string, from: number, to: number, inOrder: boolean): number {
    if (content.length - from < 1) { return -1; }
    let index: number = from > 0 ? from : 0;
    const end: number = to > 0 ? Math.min(content.length, to) : content.length;
    while (index < end) {
      const character = inOrder ? content.charAt(index) : content.charAt(content.length - index - 1);
      if (key.indexOf(character) >= 0) { return index; }
      index++;
    }
    return -1;
  }

  private static splitWithoutTrailingEmpty(content: string, delimiter: RegExp): string[] {
    const parts = content.split(delimiter);
    while (parts.length > 0 && parts[parts.length - 1] === '') { parts.pop(); }
    return parts;
  }

  private static trimControl(content: string): string {
    return content.replace(/^[\u0000-\u0020]+|[\u0000-\u0020]+$/g, '');
  }

  private static uniqueSorted(values: number[]): number[] {
    const unique: number[] = [];
    for (let index = 0; index < values.length; index++) {
      const value = values[index] ?? 0;
      if (unique.indexOf(value) < 0) { unique.push(value); }
    }
    unique.sort((left: number, right: number) => left - right);
    return unique;
  }

  private static matches(values: string, character: string): boolean {
    return character.length > 0 && values.indexOf(character) >= 0;
  }
}
