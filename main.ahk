#Requires AutoHotkey v2.0
#SingleInstance Force

g_templatesIni := A_ScriptDir "\templates.ini"
g_templates := []
g_templateBySection := Map()
g_promptMenu := Menu()
g_controlTriggers := Map(";;", true, ";c", true, ";n", true, ";h", true)
g_lineCharCount := 0
g_lineInputHook := ""

Init()

Init() {
    EnsureTemplatesIni()
    LoadTemplates()
    RegisterHotstrings()
    StartLineTracker()
    BuildPromptMenu()
}

EnsureTemplatesIni() {
    for tmpl in GetBuiltinTemplates() {
        section := tmpl["section"]

        EnsureIniString(section, "label", tmpl["label"])
        EnsureIniString(section, "trigger", tmpl["trigger"])
        EnsureIniString(section, "text", tmpl["text"])
        EnsureIniString(section, "kind", tmpl["kind"])
        EnsureIniRaw(section, "builtin", tmpl["builtin"])
        EnsureIniRaw(section, "uses", tmpl["uses"])
        EnsureIniRaw(section, "order", tmpl["order"])
    }
}

GetBuiltinTemplates() {
    templates := []
    templates.Push(Map(
        "section", "template.add",
        "label", "add:",
        "trigger", ";a",
        "text", "add: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "10"
    ))
    templates.Push(Map(
        "section", "template.fix",
        "label", "fix:",
        "trigger", ";x",
        "text", "fix: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "20"
    ))
    templates.Push(Map(
        "section", "template.update",
        "label", "update:",
        "trigger", ";u",
        "text", "update: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "30"
    ))
    templates.Push(Map(
        "section", "template.ask",
        "label", "ask: ?",
        "trigger", ";q",
        "text", "ask: ?",
        "kind", "cursor_before_last_char",
        "builtin", "1",
        "uses", "0",
        "order", "40"
    ))
    templates.Push(Map(
        "section", "template.review_code",
        "label", "review code:",
        "trigger", ";rv",
        "text", "review code: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "50"
    ))
    templates.Push(Map(
        "section", "template.explain",
        "label", "explain:",
        "trigger", ";ex",
        "text", "explain: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "60"
    ))
    templates.Push(Map(
        "section", "template.write_tests",
        "label", "write tests:",
        "trigger", ";wt",
        "text", "write tests: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "70"
    ))
    templates.Push(Map(
        "section", "template.write_docs",
        "label", "write docs:",
        "trigger", ";doc",
        "text", "write docs: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "65"
    ))
    templates.Push(Map(
        "section", "template.safe",
        "label", "minimal changes, no refactor:",
        "trigger", ";safe",
        "text", "minimal changes, no refactor: ",
        "kind", "text",
        "builtin", "1",
        "uses", "0",
        "order", "80"
    ))
    return templates
}

EnsureIniString(section, key, value) {
    global g_templatesIni

    missing := "__PROMPTLET_MISSING__"
    try current := IniRead(g_templatesIni, section, key, missing)
    catch {
        current := missing
    }
    if current = missing {
        IniWrite QuoteIniValue(value), g_templatesIni, section, key
    }
}

EnsureIniRaw(section, key, value) {
    global g_templatesIni

    missing := "__PROMPTLET_MISSING__"
    try current := IniRead(g_templatesIni, section, key, missing)
    catch {
        current := missing
    }
    if current = missing {
        IniWrite value, g_templatesIni, section, key
    }
}

LoadTemplates() {
    global g_templatesIni, g_templates, g_templateBySection

    g_templates := []
    g_templateBySection := Map()

    try sectionNames := IniRead(g_templatesIni)
    catch {
        sectionNames := ""
    }

    for section in StrSplit(sectionNames, "`n") {
        section := Trim(section, " `t`r`n")
        if section = "" || SubStr(section, 1, 9) != "template." {
            continue
        }

        tmpl := ReadTemplate(section)
        if !IsValidTemplate(tmpl) {
            continue
        }

        g_templates.Push(tmpl)
        g_templateBySection[section] := tmpl
    }
}

ReadTemplate(section) {
    global g_templatesIni

    return Map(
        "section", section,
        "label", IniRead(g_templatesIni, section, "label", ""),
        "trigger", IniRead(g_templatesIni, section, "trigger", ""),
        "text", IniRead(g_templatesIni, section, "text", ""),
        "kind", IniRead(g_templatesIni, section, "kind", "text"),
        "builtin", IniRead(g_templatesIni, section, "builtin", "0"),
        "uses", IniRead(g_templatesIni, section, "uses", "0"),
        "order", IniRead(g_templatesIni, section, "order", "1000")
    )
}

IsValidTemplate(tmpl) {
    trigger := tmpl["trigger"]
    if tmpl["section"] = "" {
        return false
    }
    if tmpl["label"] = "" {
        return false
    }
    if trigger = "" || SubStr(trigger, 1, 1) != ";" {
        return false
    }
    if tmpl["text"] = "" {
        return false
    }
    return true
}

RegisterHotstrings() {
    global g_templates, g_controlTriggers

    errors := ""
    registeredTriggers := Map()

    HotIfWinActive "ahk_exe WindowsTerminal.exe"
    Hotstring(":B0*:;;", ShowPromptMenuFromHotstring, "On")
    Hotstring(":*:;c", ClearCurrentLine, "On")
    Hotstring(":*:;n", InsertSoftNewline, "On")
    Hotstring(":*:;h", ShowControlHelp, "On")
    Hotkey("~Enter", ResetLineState, "On")
    Hotkey("~NumpadEnter", ResetLineState, "On")
    Hotkey("~^u", ResetLineState, "On")
    Hotkey("~^c", ResetLineState, "On")
    Hotkey("~Backspace", TrackBackspace, "On")

    for tmpl in g_templates {
        trigger := tmpl["trigger"]
        if g_controlTriggers.Has(trigger) || registeredTriggers.Has(trigger) {
            continue
        }

        try {
            Hotstring(":*:" trigger, UseTemplateFromHotstring.Bind(tmpl["section"]), "On")
            registeredTriggers[trigger] := true
        } catch as err {
            errors .= "Could not register " trigger " for " tmpl["label"] ": " err.Message "`n"
        }
    }
    HotIfWinActive

    if errors != "" {
        MsgBox errors, "promptlet", 0x30
    }
}

StartLineTracker() {
    global g_lineInputHook

    g_lineInputHook := InputHook("L0 V I1")
    g_lineInputHook.OnChar := TrackLineChar
    g_lineInputHook.Start()
}

TrackLineChar(ih, char) {
    global g_lineCharCount

    if !WinActive("ahk_exe WindowsTerminal.exe") {
        return
    }

    g_lineCharCount += StrLen(char)
}

TrackBackspace(*) {
    global g_lineCharCount

    if g_lineCharCount > 0 {
        g_lineCharCount -= 1
    }
}

ResetLineState(*) {
    global g_lineCharCount

    g_lineCharCount := 0
}

ConsumeTypedTrigger(trigger) {
    global g_lineCharCount

    g_lineCharCount -= StrLen(trigger)
    if g_lineCharCount < 0 {
        g_lineCharCount := 0
    }
}

RecordInsertedText(text) {
    global g_lineCharCount

    g_lineCharCount += StrLen(text)
}

IsLineStartMenuTrigger() {
    global g_lineCharCount

    return g_lineCharCount <= 2
}

ShowPromptMenuFromHotstring(*) {
    if !IsLineStartMenuTrigger() {
        return
    }

    Send "{Backspace 2}"
    ResetLineState()
    Sleep 30
    ShowPromptMenu(0)
}

ClearCurrentLine(*) {
    Send "^u"
    ResetLineState()
}

InsertSoftNewline(*) {
    Send "+{Enter}"
    ResetLineState()
}

ShowControlHelp(*) {
    ConsumeTypedTrigger(";h")

    message := "Control hotstrings:`n`n"
    message .= ";;      Open all templates menu at line start`n"
    message .= ";c      Clear the current input line`n"
    message .= ";n      Insert a multiline newline`n"
    message .= ";h      Show this help`n`n"
    message .= "After editing templates.ini, reload the script manually."

    MsgBox message, "promptlet controls", 0x40
}

ShowPromptMenu(limit := 5) {
    global g_promptMenu

    BuildPromptMenu(limit)

    CoordMode "Menu", "Screen"
    if TryGetCaretMenuPosition(&menuX, &menuY) {
        g_promptMenu.Show(menuX, menuY)
        return
    }

    if TryGetActiveWindowMenuPosition(&menuX, &menuY) {
        g_promptMenu.Show(menuX, menuY)
        return
    }

    g_promptMenu.Show(Floor(A_ScreenWidth / 2), Floor(A_ScreenHeight / 2))
}

TryGetCaretMenuPosition(&menuX, &menuY) {
    menuX := ""
    menuY := ""
    caretX := ""
    caretY := ""

    CoordMode "Caret", "Screen"
    try CaretGetPos(&caretX, &caretY)
    catch {
        return false
    }

    if caretX = "" || caretY = "" {
        return false
    }

    menuX := caretX
    menuY := caretY + 24
    return true
}

TryGetActiveWindowMenuPosition(&menuX, &menuY) {
    menuX := ""
    menuY := ""
    winX := ""
    winY := ""
    winW := ""
    winH := ""

    try WinGetPos(&winX, &winY, &winW, &winH, "A")
    catch {
        return false
    }

    if winX = "" || winY = "" || winW = "" || winH = "" {
        return false
    }

    menuX := winX + 24
    menuY := winY + winH - 96
    if menuY < winY {
        menuY := winY + 24
    }
    return true
}

BuildPromptMenu(limit := 5) {
    global g_templates, g_promptMenu

    sorted := []
    for tmpl in g_templates {
        sorted.Push(tmpl)
    }

    SortTemplates(sorted)
    g_promptMenu := Menu()
    labelCounts := Map()
    count := 0

    for tmpl in sorted {
        if limit > 0 && count >= limit {
            break
        }

        baseLabel := tmpl["label"]
        label := BuildMenuLabel(tmpl)
        if labelCounts.Has(baseLabel) {
            label := BuildMenuLabel(tmpl, true)
        }
        labelCounts[baseLabel] := true

        g_promptMenu.Add(label, UseTemplateFromMenu.Bind(tmpl["section"]))
        count += 1
    }

    if count = 0 {
        g_promptMenu.Add("(no templates)", (*) => "")
    }
}

BuildMenuLabel(tmpl, includeSection := false) {
    label := tmpl["label"] "`t" tmpl["trigger"]
    if includeSection {
        label .= "  " tmpl["section"]
    }
    return label
}

SortTemplates(templates) {
    if templates.Length < 2 {
        return
    }

    outerCount := templates.Length - 1
    Loop outerCount {
        i := A_Index
        innerCount := templates.Length - i
        Loop innerCount {
            j := A_Index
            if CompareTemplates(templates[j + 1], templates[j]) < 0 {
                tmp := templates[j]
                templates[j] := templates[j + 1]
                templates[j + 1] := tmp
            }
        }
    }
}

CompareTemplates(a, b) {
    usesA := ToInt(a["uses"])
    usesB := ToInt(b["uses"])
    if usesA > usesB {
        return -1
    }
    if usesA < usesB {
        return 1
    }

    orderA := ToInt(a["order"])
    orderB := ToInt(b["order"])
    if orderA < orderB {
        return -1
    }
    if orderA > orderB {
        return 1
    }

    return 0
}

UseTemplateFromHotstring(section, *) {
    UseTemplate(section, true)
}

UseTemplateFromMenu(section, *) {
    UseTemplate(section, false)
}

UseTemplate(section, consumeTrigger := false) {
    global g_templateBySection

    if !g_templateBySection.Has(section) {
        return
    }

    tmpl := g_templateBySection[section]
    if consumeTrigger {
        ConsumeTypedTrigger(tmpl["trigger"])
    }
    IncrementTemplateUses(tmpl)
    InsertTemplate(tmpl)
    RecordInsertedText(tmpl["text"])
}

IncrementTemplateUses(tmpl) {
    global g_templatesIni

    uses := ToInt(tmpl["uses"]) + 1
    tmpl["uses"] := uses
    IniWrite uses, g_templatesIni, tmpl["section"], "uses"
}

InsertTemplate(tmpl) {
    InsertPrompt(tmpl["text"])
    if tmpl["kind"] = "cursor_before_last_char" {
        Send "{Left}"
    }
}

InsertPrompt(text) {
    SendText text
}

QuoteIniValue(value) {
    quote := Chr(34)
    return quote StrReplace(value, quote, quote quote) quote
}

ToInt(value) {
    value := Trim(value, " `t`r`n")
    if RegExMatch(value, "^-?\d+$") {
        return value + 0
    }
    return 0
}
