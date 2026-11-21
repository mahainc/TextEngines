use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Mutex, OnceLock};

use harper_core::linting::{LintGroup, Linter, Suggestion};
use harper_core::spell::FstDictionary;
use harper_core::{remove_overlaps, Dialect, Document};
use serde::Serialize;

/// Offsets are UTF-16 code units into the input, `end` exclusive.
#[derive(Serialize)]
struct FfiLint {
    start: u32,
    end: u32,
    message: String,
    suggestion: Option<String>,
}

fn lint_group() -> &'static Mutex<LintGroup> {
    static GROUP: OnceLock<Mutex<LintGroup>> = OnceLock::new();
    GROUP.get_or_init(|| {
        Mutex::new(LintGroup::new_curated(FstDictionary::curated(), Dialect::American))
    })
}

fn utf16_offsets(chars: &[char]) -> Vec<u32> {
    let mut offsets = Vec::with_capacity(chars.len() + 1);
    let mut offset = 0u32;
    offsets.push(offset);
    for ch in chars {
        offset += ch.len_utf16() as u32;
        offsets.push(offset);
    }
    offsets
}

fn replacement(suggestion: &Suggestion, flagged: &[char]) -> String {
    match suggestion {
        Suggestion::ReplaceWith(chars) => chars.iter().collect(),
        Suggestion::InsertAfter(chars) => flagged.iter().chain(chars.iter()).collect(),
        Suggestion::Remove => String::new(),
    }
}

fn lint_text(text: &str) -> Vec<FfiLint> {
    let document = Document::new_plain_english_curated(text);
    let mut lints = {
        let mut group = lint_group().lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        group.lint(&document)
    };
    remove_overlaps(&mut lints);
    lints.sort_by_key(|lint| lint.span.start);

    let source = document.get_source();
    let offsets = utf16_offsets(source);
    lints
        .into_iter()
        .filter(|lint| lint.span.end <= source.len() && lint.span.start <= lint.span.end)
        .map(|lint| {
            let flagged = &source[lint.span.start..lint.span.end];
            FfiLint {
                start: offsets[lint.span.start],
                end: offsets[lint.span.end],
                suggestion: lint.suggestions.first().map(|s| replacement(s, flagged)),
                message: lint.message,
            }
        })
        .collect()
}

fn lint_json(text: *const c_char) -> String {
    if text.is_null() {
        return "[]".to_owned();
    }
    let text = unsafe { CStr::from_ptr(text) }.to_string_lossy();
    serde_json::to_string(&lint_text(&text)).unwrap_or_else(|_| "[]".to_owned())
}

/// Returns a JSON array of lints; release it with `harper_free_string`.
#[no_mangle]
pub extern "C" fn harper_lint_json(text: *const c_char) -> *mut c_char {
    let json = catch_unwind(AssertUnwindSafe(|| lint_json(text))).unwrap_or_else(|_| "[]".to_owned());
    CString::new(json).map_or(std::ptr::null_mut(), CString::into_raw)
}

#[no_mangle]
pub extern "C" fn harper_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(unsafe { CString::from_raw(s) });
    }
}

