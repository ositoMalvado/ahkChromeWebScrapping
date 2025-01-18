#Requires AutoHotkey v2.0


class WebScrapping {
    __New(chrome_path := '') {
        this.chrome_path := chrome_path
        this.working := true
        this.page := false
        this.working := false
        ; if !WinExist("ahk_exe chrome.exe")
        ; WinWait("ahk_exe chrome.exe")
    }

    CheckChrome() {
        if !this.CheckPage()
            if !WinExist("ahk_exe chrome.exe") {
                path := this.chrome_path ? this.chrome_path : "C:\Program Files\Google\Chrome\Application\chrome.exe"
                args := " --remote-debugging-port=9222 --remote-allow-origins=*"
                Run path args, , , &chrome_pid
                ProcessWait(chrome_pid)
            }
        WinWait("ahk_exe chrome.exe")
        this.page := this.SetAnyPage()
    }

    Close() {
        if !IsObject(this.page)
            return false
        this.page.Close()
        this.page := false
        return true
    }

    WaitForLoad() {
        if !IsObject(this.page)
            return false
        this.page.WaitForLoad()
        return true
    }

    CheckPage() {
        if !IsObject(this.page) {
            this.page := false
            return false
        }
        return true
    }

    SetAnyPage() {
        this.page := Chrome().GetPage()
        if !this.CheckPage()
            return false
        return true
    }

    SetPageByTitle(title) {
        this.CheckChrome()
        this.page := Chrome().GetPageByTitle(title, 'contains')
        return this.CheckPage()
    }
    
    SetPageByURL(url) {
        this.CheckChrome()
        this.page := Chrome().GetPageByURL(url, 'contains')
        return this.CheckPage()
    }

    Activate(){
        if !this.CheckPage()
            return false
        this.page.Activate()
        return true
    }

    Kill(){
        if !this.CheckPage()
            return false
        this.page.Kill()
        return true
    }

    Navigate(url, wait_for_load := false) {
        this.page.Call("Page.navigate", {
            url: url
        })
        if wait_for_load
            this.page.WaitForLoad()
        return this.CheckPage()
    }

    SendJS(js) {
        if !this.CheckPage()
            return false
        return this.page.Evaluate(js)
    }

    GetElement(selector) {
        if !this.CheckPage()
            return false
        js :=
            (
                '(function(){
                const element = ' selector ';
                if (element) {
                    return element.outerHTML;
                } else {
                    return false;
                }
            })()'
            )
        return this.page.Evaluate(js)["value"]
    }

    Scroll(pos := "bottom", amount := 0) {
        if (pos = "bottom") {
            ; Scroll hasta el final de la página
            this.page.Call("Runtime.evaluate", {
                expression: "window.scrollTo({top: Math.max(document.documentElement.scrollHeight, document.body.scrollHeight, document.documentElement.clientHeight), behavior: 'smooth'})"
            })
        } else if (pos = "top") {
            ; Scroll hasta el inicio de la página
            this.page.Call("Runtime.evaluate", {
                expression: "window.scrollTo({top: 0, behavior: 'smooth'})"
            })
        } else if (pos = "specific") {
            ; Scroll a una posición específica
            this.page.Call("Runtime.evaluate", {
                expression: "window.scrollTo({top: " amount ", behavior: 'smooth'})"
            })
        } else if (pos = "relative") {
            ; Scroll relativo a la posición actual
            this.page.Call("Runtime.evaluate", {
                expression: "window.scrollBy({top: " amount ", behavior: 'smooth'})"
            })
        }
    }

    GetElementPosition(selector) {
        if !this.GetElement(selector)
            return false
        js :=
            (
                '(() => {
                const element = ' selector ';
                if (!element) return "null|null|false|null|null";
                
                const rect = element.getBoundingClientRect();
                
                const viewportWidth = window.innerWidth || document.documentElement.clientWidth;
                const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
                
                const centerX = Math.round(rect.left + rect.width / 2);
                const centerY = Math.round(rect.top + rect.height / 2);
                
                const isVisible = (
                    rect.top >= 0 &&
                    rect.left >= 0 &&
                    rect.bottom <= viewportHeight &&
                    rect.right <= viewportWidth);
                
                return ``${centerX}|${centerY}|${isVisible}|${Math.round(rect.width)}|${Math.round(rect.height)}``;
            })();'
            )
        arr := StrSplit(this.page.Evaluate(js)["value"], "|")
        return {
            centerX: arr[1],
            centerY: arr[2],
            isVisible: arr[3],
            width: arr[4],
            height: arr[5]
        }
    }

    GetValue(js) {
        if !this.CheckPage()
            return false
        return this.page.Evaluate(js)["value"]
    }

    ClickElement(selector, button := "left", clickCount := 1) {
        pos := this.GetElementPosition(selector)
        if !pos
            return false
        loop clickCount
            this.page.Evaluate(selector ".click()")
        return true
    }

    ClickElementByPosition(selector, button := "left", clickCount := 1) {
        ; Obtiene la posición del elemento
        try {
            pos := this.GetElementPosition(selector)
            if !pos {
                return false
            }

            ; Verifica que las coordenadas sean números válidos
            if !IsNumber(pos.centerX) || !IsNumber(pos.centerY) {
                throw Error("Coordenadas inválidas")
            }

            ; Convertir coordenadas a números
            x := Number(pos.centerX)
            y := Number(pos.centerY)

            ; Normalizar el botón del mouse
            button := StrLower(button)
            if !InStr("left|middle|right", button) {
                button := "left"
            }

            ; Asegurar que clickCount sea un número positivo
            clickCount := Max(1, Integer(clickCount))

            ; Simular el movimiento del mouse
            this.page.Call("Input.dispatchMouseEvent", {
                type: "mouseMoved",
                x: x,
                y: y
            })

            ; Simular presionar el botón
            this.page.Call("Input.dispatchMouseEvent", {
                type: "mousePressed",
                x: x,
                y: y,
                button: button,
                clickCount: clickCount
            })

            ; Simular soltar el botón
            this.page.Call("Input.dispatchMouseEvent", {
                type: "mouseReleased",
                x: x,
                y: y,
                button: button,
                clickCount: clickCount
            })

            return true
        } catch as err {
            ; Manejo de errores
            MsgBox("Error al hacer click: " err.Message)
            return false
        }
    }

    SimulateTyping(selector, text, options := "") {
        try {
            ; Opciones por defecto
            defaultOptions := {
                focusFirst: true,
                pressEnter: false
            }

            ; Combinar opciones
            options := options ? options : defaultOptions

            ; Focus en el elemento si es requerido
            if (options.focusFirst) {
                ; Usar el método existente que sabemos que funciona
                if !this.ClickElementByPosition(selector) {
                    throw Error("No se pudo encontrar el elemento: " selector)
                }
                Sleep(50)  ; Pequeña pausa para asegurar el focus
            }

            ; Mapa de teclas especiales
            specialKeys := Map(
                "{ENTER}", { key: "Enter", code: "Enter" },
                "{TAB}", { key: "Tab", code: "Tab" },
                "{SPACE}", { key: " ", code: "Space" },
                "{BACKSPACE}", { key: "Backspace", code: "Backspace" },
                "{DELETE}", { key: "Delete", code: "Delete" },
                "{ESC}", { key: "Escape", code: "Escape" }
            )

            ; Procesar el texto
            pos := 1
            while (pos <= StrLen(text)) {
                isSpecialKey := false

                ; Revisar teclas especiales
                for special, keyInfo in specialKeys {
                    if (SubStr(text, pos, StrLen(special)) = special) {
                        ; Enviar eventos keyDown y keyUp para teclas especiales
                        this.page.Call("Input.dispatchKeyEvent", {
                            type: "keyDown",
                            key: keyInfo.key,
                            code: keyInfo.code
                        })

                        this.page.Call("Input.dispatchKeyEvent", {
                            type: "keyUp",
                            key: keyInfo.key,
                            code: keyInfo.code
                        })

                        pos += StrLen(special)
                        isSpecialKey := true
                        break
                    }
                }

                if (!isSpecialKey) {
                    ; Procesar carácter normal
                    char := SubStr(text, pos, 1)

                    ; Enviar eventos keyDown y keyUp para caracteres normales
                    this.page.Call("Input.dispatchKeyEvent", {
                        type: "keyDown",
                        key: char,
                        text: char,
                        windowsVirtualKeyCode: Ord(char)
                    })

                    this.page.Call("Input.dispatchKeyEvent", {
                        type: "keyUp",
                        key: char,
                        text: char,
                        windowsVirtualKeyCode: Ord(char)
                    })

                    pos++
                }

                Sleep(10)  ; Pequeña pausa entre caracteres
            }

            ; Presionar Enter al final si está configurado
            if (options.pressEnter) {
                this.page.Call("Input.dispatchKeyEvent", {
                    type: "keyDown",
                    key: "Enter",
                    code: "Enter"
                })

                this.page.Call("Input.dispatchKeyEvent", {
                    type: "keyUp",
                    key: "Enter",
                    code: "Enter"
                })
            }

            return true
        } catch as err {
            MsgBox("Error en SimulateTyping: " err.Message)
            return false
        }
    }

    SimulatePaste(selector, text, options := "") {
        try {
            ; Opciones por defecto
            defaultOptions := { focusFirst: true }

            ; Combinar opciones
            options := options ? options : defaultOptions

            ; Focus en el elemento si es requerido
            if (options.focusFirst) {
                ; Usar el método existente que sabemos que funciona
                if !this.ClickElementByPosition(selector) {
                    throw Error("No se pudo encontrar el elemento: " selector)
                }
                Sleep(50)  ; Pequeña pausa para asegurar el focus
            }

            ; Construir el código JavaScript para pegar texto
            js :=
                (
                    '(() => {
                    const element = ' selector ';
                    if (element) {
                        element.value = "' text '";
                        element.dispatchEvent(new Event(`'input`', { bubbles: true }));
                        return true;
                    } else {
                        return false;
                    }
                })()'
                )

            ; Evaluar el JavaScript en la página
            result := this.page.Evaluate(js)["value"]

            if !result {
                throw Error("No se pudo establecer el valor del elemento: " selector)
            }

            return true
        } catch as err {
            MsgBox("Error en SimulatePaste: " err.Message)
            return false
        }
    }

}
/************************************************************************
 * @description: Modify from G33kDude's Chrome.ahk v1
 * @author thqby
 * @date 2023/05/10
 * @version 1.0.4
 ***********************************************************************/

class Chrome {
    static _http := ComObject('WinHttp.WinHttpRequest.5.1'), Prototype.NewTab := this.Prototype.NewPage
    static FindInstance(exename := 'Chrome.exe', debugport := 0) {
        items := Map(), filter_items := Map()
        for item in ComObjGet('winmgmts:').ExecQuery("SELECT CommandLine, ProcessID FROM Win32_Process WHERE Name = '" exename "' AND CommandLine LIKE '% --remote-debugging-port=%'"
        )
            (!items.Has(parentPID := ProcessGetParent(item.ProcessID)) && items[item.ProcessID] := [parentPID, item.CommandLine])
        for pid, item in items
            if !items.Has(item[1]) && (!debugport || InStr(item[2], ' --remote-debugging-port=' debugport))
                filter_items[pid] := item[2]
        for pid, cmd in filter_items
            if RegExMatch(cmd, 'i) --remote-debugging-port=(\d+)', &m)
                return { Base: this.Prototype, DebugPort: m[1], PID: pid }
    }

    /**
     * @param ProfilePath - Path to the user profile directory to use. Will use the standard if left blank.
     * @param URLs        - The page or array of pages for Chrome to load when it opens
     * @param Flags       - Additional flags for Chrome when launching
     * @param ChromePath  - Path to Chrome or Edge, will detect from start menu when left blank
     * @param DebugPort   - What port should Chrome's remote debugging server run on
     */
    __New(URLs := '', Flags := '', ChromePath := '', DebugPort := 9222, ProfilePath := '') {
        ; Verify ChromePath
        if !ChromePath
            try FileGetShortcut A_StartMenuCommon '\Programs\Chrome.lnk', &ChromePath
            catch
                ChromePath := RegRead(
                    'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Chrome.exe', ,
                    'C:\Program Files (x86)\Google\Chrome\Application\Chrome.exe')
        if !FileExist(ChromePath) && !FileExist(ChromePath :=
            'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')
            throw Error('Chrome/Edge could not be found')
        ; Verify DebugPort
        if !IsInteger(DebugPort) || (DebugPort <= 0)
            throw Error('DebugPort must be a positive integer')
        this.DebugPort := DebugPort, URLString := ''

        SplitPath(ChromePath, &exename)
        URLs := URLs is Array ? URLs : URLs && URLs is String ? [URLs] : []
        if instance := Chrome.FindInstance(exename, DebugPort) {
            this.PID := instance.PID, http := Chrome._http
            for url in URLs
                http.Open('PUT', 'http://127.0.0.1:' this.DebugPort '/json/new?' url), http.Send()
            return
        }

        ; Verify ProfilePath
        if (ProfilePath && !FileExist(ProfilePath))
            DirCreate(ProfilePath)

        ; Escape the URL(s)
        for url in URLs
            URLString .= ' ' CliEscape(url)

        hasother := ProcessExist(exename)
        Run(CliEscape(ChromePath) ' --remote-debugging-port=' this.DebugPort ' --remote-allow-origins=*'
        (ProfilePath ? ' --user-data-dir=' CliEscape(ProfilePath) : '')
        (Flags ? ' ' Flags : '') URLString, , , &PID)
        if (hasother && Sleep(600) || !instance := Chrome.FindInstance(exename, this.DebugPort))
            throw Error(Format('{1:} is not running in debug mode. Try closing all {1:} processes and try again',
                exename))
        this.PID := PID

        CliEscape(Param) => '"' RegExReplace(Param, '(\\*)"', '$1$1\"') '"'
    }

    /**
     * End Chrome by terminating the process.
     */
    Kill() {
        ProcessClose(this.PID)
    }

    /**
     * Queries Chrome for a list of pages that expose a debug interface.
     * In addition to standard tabs, these include pages such as extension
     * configuration pages.
     */
    GetPageList() {
        http := Chrome._http
        try {
            http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json')
            http.Send()
            return JSON.parse(http.responseText)
        } catch
            return []
    }

    FindPages(opts, MatchMode := 'exact') {
        Pages := []
        for PageData in this.GetPageList() {
            fg := true
            for k, v in (opts is Map ? opts : opts.OwnProps())
                if !((MatchMode = 'exact' && PageData[k] = v) || (MatchMode = 'contains' && InStr(PageData[k], v))
                || (MatchMode = 'startswith' && InStr(PageData[k], v) == 1) || (MatchMode = 'regex' && PageData[k] ~= v
                )) {
                    fg := false
                    break
                }
            if (fg)
                Pages.Push(PageData)
        }
        return Pages
    }

    NewPage(url := 'about:blank', fnCallback?) {
        http := Chrome._http
        http.Open('PUT', 'http://127.0.0.1:' this.DebugPort '/json/new?' url), http.Send()
        if ((PageData := JSON.parse(http.responseText)).Has('webSocketDebuggerUrl'))
            return Chrome.Page(StrReplace(PageData['webSocketDebuggerUrl'], 'localhost', '127.0.0.1'), fnCallback?)
    }

    ClosePage(opts, MatchMode := 'exact') {
        http := Chrome._http
        switch Type(opts) {
            case 'String':
                return (http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts), http.Send())
            case 'Map':
                if opts.Has('id')
                    return (http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts['id']), http.Send())
            case 'Object':
                if opts.HasProp('id')
                    return (http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts.id), http.Send())
        }
        for page in this.FindPages(opts, MatchMode)
            http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' page['id']), http.Send()
    }

    ActivatePage(opts, MatchMode := 'exact') {
        http := Chrome._http
        for page in this.FindPages(opts, MatchMode)
            return (http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/activate/' page['id']), http.Send())
    }
    /**
     * Returns a connection to the debug interface of a page that matches the
     * provided criteria. When multiple pages match the criteria, they appear
     * ordered by how recently the pages were opened.
     * 
     * Key        - The key from the page list to search for, such as 'url' or 'title'
     * Value      - The value to search for in the provided key
     * MatchMode  - What kind of search to use, such as 'exact', 'contains', 'startswith', or 'regex'
     * Index      - If multiple pages match the given criteria, which one of them to return
     * fnCallback - A function to be called whenever message is received from the page, `msg => void`
     */
    GetPageBy(Key, Value, MatchMode := 'exact', Index := 1, fnCallback?) {
        static match_fn := {
            contains: InStr,
            exact: (a, b) => a = b,
            regex: (a, b) => a ~= b,
            startswith: (a, b) => InStr(a, b) == 1
        }
        Count := 0, Fn := match_fn.%MatchMode%
        for PageData in this.GetPageList()
            if Fn(PageData[Key], Value) && ++Count == Index
                return Chrome.Page(PageData['webSocketDebuggerUrl'], fnCallback?)
    }

    ; Shorthand for GetPageBy('url', Value, 'startswith')
    GetPageByURL(Value, MatchMode := 'startswith', Index := 1, fnCallback?) {
        return this.GetPageBy('url', Value, MatchMode, Index, fnCallback?)
    }

    ; Shorthand for GetPageBy('title', Value, 'startswith')
    GetPageByTitle(Value, MatchMode := 'startswith', Index := 1, fnCallback?) {
        return this.GetPageBy('title', Value, MatchMode, Index, fnCallback?)
    }

    /**
     * Shorthand for GetPageBy('type', Type, 'exact')
     * 
     * The default type to search for is 'page', which is the visible area of
     * a normal Chrome tab.
     */
    GetPage(Index := 1, Type := 'page', fnCallback?) {
        return this.GetPageBy('type', Type, 'exact', Index, fnCallback?)
    }

    ; Connects to the debug interface of a page given its WebSocket URL.
    class Page extends WebSocket {
        _index := 0, _responses := Map(), _callback := 0
        /**
         * @param url the url of webscoket
         * @param events callback function, `(msg) => void`
         */
        __New(url, events := 0) {
            super.__New(url)
            this._callback := events
            pthis := ObjPtr(this)
            SetTimer(this.KeepAlive := () => ObjFromPtrAddRef(pthis)('Browser.getVersion', , false), 25000)
        }
        __Delete() {
            if !this.KeepAlive
                return
            SetTimer(this.KeepAlive, 0), this.KeepAlive := 0
            super.__Delete()
        }

        Call(DomainAndMethod, Params?, WaitForResponse := true) {
            if (this.readyState != 1)
                throw Error('Not connected to tab')

            ; Use a temporary variable for ID in case more calls are made
            ; before we receive a response.
            if !ID := this._index += 1
                ID := this._index += 1
            this.sendText(JSON.stringify(Map('id', ID, 'params', Params ?? {}, 'method', DomainAndMethod), 0))
            if (!WaitForResponse)
                return

            ; Wait for the response
            this._responses[ID] := false
            while (this.readyState = 1 && !this._responses[ID])
                Sleep(20)

            ; Get the response, check if it's an error
            if !response := this._responses.Delete(ID)
                throw Error('Not connected to tab')
            if !(response is Map)
                return response
            if (response.Has('error'))
                throw Error('Chrome indicated error in response', , JSON.stringify(response['error']))
            try return response['result']
        }
        Evaluate(JS) {
            response := this('Runtime.evaluate', {
                expression: JS,
                objectGroup: 'console',
                includeCommandLineAPI: JSON.true,
                silent: JSON.false,
                returnByValue: JSON.false,
                userGesture: JSON.true,
                awaitPromise: JSON.false
            })
            if (response is Map) {
                if (response.Has('exceptionDetails'))
                    throw Error(response['result']['description'], , JSON.stringify(response['exceptionDetails']))
                return response['result']
            }
        }

        Close() {
            RegExMatch(this.url, 'ws://[\d\.]+:(\d+)/devtools/page/(.+)$', &m)
            http := Chrome._http, http.Open('GET', 'http://127.0.0.1:' m[1] '/json/close/' m[2]), http.Send()
            this.__Delete()
        }

        Activate() {
            http := Chrome._http, RegExMatch(this.url, 'ws://[\d\.]+:(\d+)/devtools/page/(.+)$', &m)
            http.Open('GET', 'http://127.0.0.1:' m[1] '/json/activate/' m[2]), http.Send()
        }

        WaitForLoad(DesiredState := 'complete', Interval := 100) {
            while this.Evaluate('document.readyState')['value'] != DesiredState
                Sleep Interval
        }
        onClose(*) {
            try this.reconnect()
            catch WebSocket.Error
                this.__Delete()
        }
        onMessage(msg) {
            data := JSON.parse(msg)
            if this._responses.Has(id := data.Get('id', 0))
                this._responses[id] := data
            try (this._callback)(data)
        }
    }
}

/************************************************************************
 * @description The websocket client implemented through winhttp,
 * requires that the system version be no less than win8.
 * @author thqby
 * @date 2024/01/27
 * @version 1.0.7
 ***********************************************************************/

#DllLoad winhttp.dll

class JSON {
    static null := ComValue(1, 0), true := ComValue(0xB, 1), false := ComValue(0xB, 0)

    /**
     * Converts a AutoHotkey Object Notation JSON string into an object.
     * @param text A valid JSON string.
     * @param keepbooltype convert true/false/null to JSON.true / JSON.false / JSON.null where it's true, otherwise 1 / 0 / ''
     * @param as_map object literals are converted to map, otherwise to object
     */
    static parse(text, keepbooltype := false, as_map := true) {
        keepbooltype ? (_true := this.true, _false := this.false, _null := this.null) : (_true := true, _false := false,
            _null := "")
        as_map ? (map_set := (maptype := Map).Prototype.Set) : (map_set := (obj, key, val) => obj.%key% := val, maptype :=
        Object)
        NQ := "", LF := "", LP := 0, P := "", R := ""
        D := [C := (A := InStr(text := LTrim(text, " `t`r`n"), "[") = 1) ? [] : maptype()], text := LTrim(SubStr(text,
            2), " `t`r`n"), L := 1, N := 0, V := K := "", J := C, !(Q := InStr(text, '"') != 1) ? text := LTrim(text,
                '"') : ""
        loop parse text, '"' {
            Q := NQ ? 1 : !Q
            NQ := Q && RegExMatch(A_LoopField, '(^|[^\\])(\\\\)*\\$')
            if !Q {
                if (t := Trim(A_LoopField, " `t`r`n")) = "," || (t = ":" && V := 1)
                    continue
                else if t && (InStr("{[]},:", SubStr(t, 1, 1)) || A && RegExMatch(t,
                    "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]")) {
                    loop parse t {
                        if N && N--
                            continue
                        if InStr("`n`r `t", A_LoopField)
                            continue
                        else if InStr("{[", A_LoopField) {
                            if !A && !V
                                throw Error("Malformed JSON - missing key.", 0, t)
                            C := A_LoopField = "[" ? [] : maptype(), A ? D[L].Push(C) : map_set(D[L], K, C), D.Has(++L) ?
                                D[L] := C : D.Push(C), V := "", A := Type(C) = "Array"
                            continue
                        } else if InStr("]}", A_LoopField) {
                            if !A && V
                                throw Error("Malformed JSON - missing value.", 0, t)
                            else if L = 0
                                throw Error("Malformed JSON - to many closing brackets.", 0, t)
                            else C := --L = 0 ? "" : D[L], A := Type(C) = "Array"
                        } else if !(InStr(" `t`r,", A_LoopField) || (A_LoopField = ":" && V := 1)) {
                            if RegExMatch(SubStr(t, A_Index),
                            "m)^(null|false|true|-?\d+(\.\d*(e[-+]\d+)?)?)\s*[,}\]\r\n]", &R) && (N := R.Len(0) - 2, R :=
                            R.1, 1) {
                                if A
                                    C.Push(R = "null" ? _null : R = "true" ? _true : R = "false" ? _false : IsNumber(R) ?
                                        R + 0 : R)
                                else if V
                                    map_set(C, K, R = "null" ? _null : R = "true" ? _true : R = "false" ? _false :
                                        IsNumber(R) ? R + 0 : R), K := V := ""
                                else throw Error("Malformed JSON - missing key.", 0, t)
                            } else {
                                ; Added support for comments without '"'
                                if A_LoopField == '/' {
                                    nt := SubStr(t, A_Index + 1, 1), N := 0
                                    if nt == '/' {
                                        if nt := InStr(t, '`n', , A_Index + 2)
                                            N := nt - A_Index - 1
                                    } else if nt == '*' {
                                        if nt := InStr(t, '*/', , A_Index + 2)
                                            N := nt + 1 - A_Index
                                    } else nt := 0
                                    if N
                                        continue
                                }
                                throw Error("Malformed JSON - unrecognized character.", 0, A_LoopField " in " t)
                            }
                        }
                    }
                } else if A || InStr(t, ':') > 1
                    throw Error("Malformed JSON - unrecognized character.", 0, SubStr(t, 1, 1) " in " t)
            } else if NQ && (P .= A_LoopField '"', 1)
                continue
            else if A
                LF := P A_LoopField, C.Push(InStr(LF, "\") ? UC(LF) : LF), P := ""
            else if V
                LF := P A_LoopField, map_set(C, K, InStr(LF, "\") ? UC(LF) : LF), K := V := P := ""
            else
                LF := P A_LoopField, K := InStr(LF, "\") ? UC(LF) : LF, P := ""
        }
        return J
        UC(S, e := 1) {
            static m := Map('"', '"', "a", "`a", "b", "`b", "t", "`t", "n", "`n", "v", "`v", "f", "`f", "r", "`r")
            local v := ""
            loop parse S, "\"
                if !((e := !e) && A_LoopField = "" ? v .= "\" : !e ? (v .= A_LoopField, 1) : 0)
                    v .= (t := m.Get(SubStr(A_LoopField, 1, 1), 0)) ? t SubStr(A_LoopField, 2) :
                        (t := RegExMatch(A_LoopField, "i)^(u[\da-f]{4}|x[\da-f]{2})\K")) ?
                            Chr("0x" SubStr(A_LoopField, 2, t - 2)) SubStr(A_LoopField, t) : "\" A_LoopField,
                    e := A_LoopField = "" ? e : !e
            return v
        }
    }

    /**
     * Converts a AutoHotkey Array/Map/Object to a Object Notation JSON string.
     * @param obj A AutoHotkey value, usually an object or array or map, to be converted.
     * @param expandlevel The level of JSON string need to expand, by default expand all.
     * @param space Adds indentation, white space, and line break characters to the return-value JSON text to make it easier to read.
     */
    static stringify(obj, expandlevel := unset, space := "  ") {
        expandlevel := IsSet(expandlevel) ? Abs(expandlevel) : 10000000
        return Trim(CO(obj, expandlevel))
        CO(O, J := 0, R := 0, Q := 0) {
            static M1 := "{", M2 := "}", S1 := "[", S2 := "]", N := "`n", C := ",", S := "- ", E := "", K := ":"
            if (OT := Type(O)) = "Array" {
                D := !R ? S1 : ""
                for key, value in O {
                    F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
                    Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" &&
                        ObjOwnPropCount(value) = 0)) ? "{}" : ""
                    D .= (J > R ? "`n" CL(R + 2) : "") (F ? (%F%1 (Z ? "" : CO(value, J, R + 1, F)) %F%2) : ES(value)) (
                        OT = "Array" && O.Length = A_Index ? E : C)
                }
            } else {
                D := !R ? M1 : ""
                for key, value in (OT := Type(O)) = "Map" ? (Y := 1, O) : (Y := 0, O.OwnProps()) {
                    F := (VT := Type(value)) = "Array" ? "S" : InStr("Map,Object", VT) ? "M" : E
                    Z := VT = "Array" && value.Length = 0 ? "[]" : ((VT = "Map" && value.count = 0) || (VT = "Object" &&
                        ObjOwnPropCount(value) = 0)) ? "{}" : ""
                    D .= (J > R ? "`n" CL(R + 2) : "") (Q = "S" && A_Index = 1 ? M1 : E) ES(key) K (F ? (%F%1 (Z ? "" :
                        CO(value, J, R + 1, F)) %F%2) : ES(value)) (Q = "S" && A_Index = (Y ? O.count : ObjOwnPropCount(
                            O)) ? M2 : E) (J != 0 || R ? (A_Index = (Y ? O.count : ObjOwnPropCount(O)) ? E : C) : E)
                    if J = 0 && !R
                        D .= (A_Index < (Y ? O.count : ObjOwnPropCount(O)) ? C : E)
                }
            }
            if J > R
                D .= "`n" CL(R + 1)
            if R = 0
                D := RegExReplace(D, "^\R+") (OT = "Array" ? S2 : M2)
            return D
        }
        ES(S) {
            switch Type(S) {
                case "Float":
                    if (v := '', d := InStr(S, 'e'))
                        v := SubStr(S, d), S := SubStr(S, 1, d - 1)
                    if ((StrLen(S) > 17) && (d := RegExMatch(S, "(99999+|00000+)\d{0,3}$")))
                        S := Round(S, Max(1, d - InStr(S, ".") - 1))
                    return S v
                case "Integer":
                    return S
                case "String":
                    S := StrReplace(S, "\", "\\")
                    S := StrReplace(S, "`t", "\t")
                    S := StrReplace(S, "`r", "\r")
                    S := StrReplace(S, "`n", "\n")
                    S := StrReplace(S, "`b", "\b")
                    S := StrReplace(S, "`f", "\f")
                    S := StrReplace(S, "`v", "\v")
                    S := StrReplace(S, '"', '\"')
                    return '"' S '"'
                default:
                    return S == this.true ? "true" : S == this.false ? "false" : "null"
            }
        }
        CL(i) {
            loop (s := "", space ? i - 1 : 0)
                s .= space
            return s
        }
    }
}

class WebSocket {
    Ptr := 0, async := 0, readyState := 0, url := ''

    ; The array of HINTERNET handles, [hSession, hConnect, hRequest(onOpen) | hWebSocket?]
    HINTERNETs := []

    ; when request is opened
    onOpen() => 0
    ; when server sent a close frame
    onClose(status, reason) => 0
    ; when server sent binary message
    onData(data, size) => 0
    ; when server sent UTF-8 message
    onMessage(msg) => 0
    reconnect() => 0

    /**
     * @param {String} Url the url of websocket
     * @param {Object} Events an object of `{open:(this)=>void,data:(this, data, size)=>bool,message:(this, msg)=>bool,close:(this, status, reason)=>void}`
     * @param {Integer} Async Use asynchronous mode
     * @param {Object|Map|String} Headers Additional request headers to use when creating connections
     * @param {Integer} TimeOut Set resolve, connect, send and receive timeout
     */
    __New(Url, Events := 0, Async := true, Headers := '', TimeOut := 0, InitialSize := 8192) {
        static contexts := Map()
        if (!RegExMatch(Url,
            'i)^((?<SCHEME>wss?)://)?((?<USERNAME>[^:]+):(?<PASSWORD>.+)@)?(?<HOST>[^/:\s]+)(:(?<PORT>\d+))?(?<PATH>/\S*)?$', &
            m))
            throw WebSocket.Error('Invalid websocket url')
        if !hSession := DllCall('Winhttp\WinHttpOpen', 'ptr', 0, 'uint', 0, 'ptr', 0, 'ptr', 0, 'uint', Async ?
            0x10000000 : 0, 'ptr')
            throw WebSocket.Error()
        this.async := Async := !!Async, this.url := Url
        this.HINTERNETs.Push(hSession)
        port := m.PORT ? Integer(m.PORT) : m.SCHEME = 'ws' ? 80 : 443
        dwFlags := m.SCHEME = 'wss' ? 0x800000 : 0
        if TimeOut
            DllCall('Winhttp\WinHttpSetTimeouts', 'ptr', hSession, 'int', TimeOut, 'int', TimeOut, 'int', TimeOut,
                'int', TimeOut, 'int')
        if !hConnect := DllCall('Winhttp\WinHttpConnect', 'ptr', hSession, 'wstr', m.HOST, 'ushort', port, 'uint', 0,
            'ptr')
            throw WebSocket.Error()
        this.HINTERNETs.Push(hConnect)
        switch Type(Headers) {
            case 'Object', 'Map':
                s := ''
                for k, v in Headers is Map ? Headers : Headers.OwnProps()
                    s .= '`r`n' k ': ' v
                Headers := LTrim(s, '`r`n')
            case 'String':
            default:
                Headers := ''
        }
        if (Events) {
            for k, v in Events.OwnProps()
                if (k ~= 'i)^(open|data|message|close)$')
                    this.DefineProp('on' k, { call: v })
        }
        if (Async) {
            this.DefineProp('shutdown', { call: async_shutdown })
            .DefineProp('receive', { call: receive })
            .DefineProp('_send', { call: async_send })
        } else this.__cache_size := InitialSize
        connect(this), this.DefineProp('reconnect', { call: connect })

        connect(self) {
            if !self.HINTERNETs.Length
                throw WebSocket.Error('The connection is closed')
            self.shutdown()
            if !hRequest := DllCall('Winhttp\WinHttpOpenRequest', 'ptr', hConnect, 'wstr', 'GET', 'wstr', m.PATH, 'ptr',
                0, 'ptr', 0, 'ptr', 0, 'uint', dwFlags, 'ptr')
                throw WebSocket.Error()
            self.HINTERNETs.Push(hRequest), self.onOpen()
            if (Headers)
                DllCall('Winhttp\WinHttpAddRequestHeaders', 'ptr', hRequest, 'wstr', Headers, 'uint', -1, 'uint',
                    0x20000000, 'int')
            if (!DllCall('Winhttp\WinHttpSetOption', 'ptr', hRequest, 'uint', 114, 'ptr', 0, 'uint', 0, 'int')
            || !DllCall('Winhttp\WinHttpSendRequest', 'ptr', hRequest, 'ptr', 0, 'uint', 0, 'ptr', 0, 'uint', 0, 'uint',
                0, 'uptr', 0, 'int')
            || !DllCall('Winhttp\WinHttpReceiveResponse', 'ptr', hRequest, 'ptr', 0)
            || !DllCall('Winhttp\WinHttpQueryHeaders', 'ptr', hRequest, 'uint', 19, 'ptr', 0, 'wstr', status := '00000',
                'uint*', 10, 'ptr', 0, 'int')
            || status != '101')
                throw IsSet(status) ? WebSocket.Error('Invalid status: ' status) : WebSocket.Error()
            if !self.Ptr := DllCall('Winhttp\WinHttpWebSocketCompleteUpgrade', 'ptr', hRequest, 'ptr', 0)
                throw WebSocket.Error()
            DllCall('Winhttp\WinHttpCloseHandle', 'ptr', self.HINTERNETs.Pop())
            self.HINTERNETs.Push(self.Ptr), self.readyState := 1
            (Async && async_receive(self))
        }

        async_receive(self) {
            static on_read_complete := get_sync_callback(), hHeap := DllCall('GetProcessHeap', 'ptr')
            static msg_gui := Gui(), wm_ahkmsg := DllCall('RegisterWindowMessage', 'str', 'AHK_WEBSOCKET_STATUSCHANGE',
                'uint')
            static pHeapReAlloc := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'kernel32', 'ptr'
            ), 'astr', 'HeapReAlloc', 'ptr')
            static pSendMessageW := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'user32', 'ptr'),
            'astr', 'SendMessageW', 'ptr')
            static pWinHttpWebSocketReceive := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str',
                'winhttp', 'ptr'), 'astr', 'WinHttpWebSocketReceive', 'ptr')
            static _ := (OnMessage(wm_ahkmsg, WEBSOCKET_READ_WRITE_COMPLETE, 0xff), DllCall('SetParent', 'ptr', msg_gui
                .Hwnd, 'ptr', -3))
            ; #DllLoad E:\projects\test\test\x64\Debug\test.dll
            ; on_read_complete := DllCall('GetProcAddress', 'ptr', DllCall('GetModuleHandle', 'str', 'test', 'ptr'), 'astr', 'WINHTTP_STATUS_READ_COMPLETE', 'ptr')
            NumPut('ptr', pws := ObjPtr(self), 'ptr', msg_gui.Hwnd, 'uint', wm_ahkmsg, 'uint', InitialSize, 'ptr',
            hHeap,
            'ptr', cache := DllCall('HeapAlloc', 'ptr', hHeap, 'uint', 0, 'uptr', InitialSize, 'ptr'), 'uptr', 0,
            'uptr', InitialSize,
            'ptr', pHeapReAlloc, 'ptr', pSendMessageW, 'ptr', pWinHttpWebSocketReceive,
            contexts[pws] := context := Buffer(11 * A_PtrSize)), self.__send_queue := []
            context.DefineProp('__Delete', { call: self => DllCall('HeapFree', 'ptr', hHeap, 'uint', 0, 'ptr', NumGet(
                self, 3 * A_PtrSize + 8, 'ptr')) })
            DllCall('Winhttp\WinHttpSetOption', 'ptr', self, 'uint', 45, 'ptr*', context.Ptr, 'uint', A_PtrSize)
            DllCall('Winhttp\WinHttpSetStatusCallback', 'ptr', self, 'ptr', on_read_complete, 'uint', 0x80000, 'uptr',
                0, 'ptr')
            if err := DllCall('Winhttp\WinHttpWebSocketReceive', 'ptr', self, 'ptr', cache, 'uint', InitialSize,
                'uint*', 0, 'uint*', 0)
                self.onError(err)
        }

        static WEBSOCKET_READ_WRITE_COMPLETE(wp, lp, msg, hwnd) {
            static map_has := Map.Prototype.Has
            if !map_has(contexts, ws := NumGet(wp, 'ptr')) || (ws := ObjFromPtrAddRef(ws)).readyState != 1
                return
            switch lp {
                case 5:		; WRITE_COMPLETE
                    try ws.__send_queue.Pop()
                case 4:		; WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE
                    if err := NumGet(wp, A_PtrSize, 'uint')
                        return ws.onError(err)
                    rea := ws.QueryCloseStatus(), ws.shutdown()
                    return ws.onClose(rea.status, rea.reason)
                default:	; WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE, WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE
                    data := NumGet(wp, A_PtrSize, 'ptr')
                    size := NumGet(wp, 2 * A_PtrSize, 'uptr')
                    if lp == 2
                        return ws.onMessage(StrGet(data, size, 'utf-8'))
                    else return ws.onData(data, size)
            }
        }

        static async_send(self, type, buf, size) {
            if (self.readyState != 1)
                throw WebSocket.Error('websocket is disconnected')
            (q := self.__send_queue).InsertAt(1, buf)
            while (err := DllCall('Winhttp\WinHttpWebSocketSend', 'ptr', self, 'uint', type, 'ptr', buf, 'uint', size,
                'uint')) = 4317 && A_Index < 60
                Sleep(15)
            if err
                q.RemoveAt(1), self.onError(err)
        }

        static async_shutdown(self) {
            if self.Ptr
                DllCall('Winhttp\WinHttpSetOption', 'ptr', self, 'uint', 45, 'ptr*', 0, 'uint', A_PtrSize)
            (WebSocket.Prototype.shutdown)(self)
            try contexts.Delete(ObjPtr(self))
        }

        static get_sync_callback() {
            mcodes := [
                'g+wMVot0JBiF9g+E0QAAAItEJBw9AAAQAHUVi0YkagVW/3YI/3YE/9Beg8QMwhQAPQAACAAPhaYAAACLBolEJASLRCQgU1VXi1AEx0QkFAAAAADHRCQYAAAAAIP6BHRsi04Yi+qLAI0MAYlOGIPlAXV2i0YUiUQkFI1EJBBSUP92CItGJP92BIlMJCjHRhgAAAAA/9CNfhyFwHQHi14MOx91UYsHK0YYagBqAFCLRhQDRhhQ/3QkMItGKP/QhcB0HT3dEAAAdBaJRCQUagSNRCQUUP92CItGJP92BP/QX11bXoPEDMIUAIteHI1+HDvLcrED24tGIFP/dhRqAP92EP/QhcB0B4lGFIkf65aF7XSSx0QkFA4AB4DrsQ==',
                'SIXSD4QvAQAASIlcJCBBVkiD7FBIi9pMi/FBgfgAABAAdR9Ii0sITIvCi1IQQbkFAAAA/1NASItcJHhIg8RQQV7DQYH4AAAIAA+F3gAAAEiLAkljUQRIiWwkYEiJRCQwM8BIiXQkaEiJfCRwSMdEJDgAAAAASIlEJECD+gQPhIYAAABFiwGL6kiLQyhNjQQATIlDKIPlAQ+FnAAAAEiLQyBMi8qLUxBIi0sITIlEJEBMjUQkMEiJRCQ4SMdDKAAAAAD/U0BIjXswSIXAdAiLcxRIOzd1c0SLB0UzyUiLUyBJi85EK0MoSANTKEjHRCQgAAAAAP9TSIXAdCM93RAAAHQci8BIiUQkOItTEEyNRCQwSItLCEG5BAAAAP9TQEiLdCRoSItsJGBIi3wkcEiLXCR4SIPEUEFew0iLczBIjXswTDvGcpBIA/ZMi0MgTIvOSItLGDPS/1M4SIXAdAxIiUMgSIk36Wz///+F7Q+EZP///0jHRCQ4DgAHgOuM']
            DllCall('crypt32\CryptStringToBinary', 'str', hex := mcodes[A_PtrSize >> 2], 'uint', 0, 'uint', 1, 'ptr', 0,
                'uint*', &s := 0, 'ptr', 0, 'ptr', 0) &&
            DllCall('crypt32\CryptStringToBinary', 'str', hex, 'uint', 0, 'uint', 1, 'ptr', code := Buffer(s), 'uint*', &
            s, 'ptr', 0, 'ptr', 0) &&
            DllCall('VirtualProtect', 'ptr', code, 'uint', s, 'uint', 0x40, 'uint*', 0)
            return code
        }

        static receive(*) {
            throw WebSocket.Error('Used only in synchronous mode')
        }
    }

    __Delete() {
        this.shutdown()
        while (this.HINTERNETs.Length)
            DllCall('Winhttp\WinHttpCloseHandle', 'ptr', this.HINTERNETs.Pop())
    }

    onError(err, what := 0) {
        if err != 12030
            throw WebSocket.Error(err, what - 5)
        if this.readyState == 3
            return
        this.readyState := 3
        try this.onClose(1006, '')
    }

    class Error extends Error {
        __New(err := A_LastError, what := -4) {
            static module := DllCall('GetModuleHandle', 'str', 'winhttp', 'ptr')
            if err is Integer
                if (DllCall("FormatMessage", "uint", 0x900, "ptr", module, "uint", err, "uint", 0, "ptr*", &pstr := 0,
                    "uint", 0, "ptr", 0), pstr)
                    err := (msg := StrGet(pstr), DllCall('LocalFree', 'ptr', pstr), msg)
                else err := OSError(err).Message
            super.__New(err, what)
        }
    }

    queryCloseStatus() {
        if (!DllCall('Winhttp\WinHttpWebSocketQueryCloseStatus', 'ptr', this, 'ushort*', &usStatus := 0, 'ptr', vReason :=
            Buffer(123), 'uint', 123, 'uint*', &len := 0))
            return { status: usStatus, reason: StrGet(vReason, len, 'utf-8') }
        else if (this.readyState > 1)
            return { status: 1006, reason: '' }
    }

    /** @param type BINARY_MESSAGE = 0, BINARY_FRAGMENT = 1, UTF8_MESSAGE = 2, UTF8_FRAGMENT = 3 */
    _send(type, buf, size) {
        if (this.readyState != 1)
            throw WebSocket.Error('websocket is disconnected')
        if err := DllCall('Winhttp\WinHttpWebSocketSend', 'ptr', this, 'uint', type, 'ptr', buf, 'uint', size, 'uint')
            return this.onError(err)
    }

    ; sends a utf-8 string to the server
    sendText(str) {
        if (size := StrPut(str, 'utf-8') - 1) {
            StrPut(str, buf := Buffer(size), 'utf-8')
            this._send(2, buf, size)
        } else
            this._send(2, 0, 0)
    }

    send(buf) => this._send(0, buf, buf.Size)

    receive() {
        if (this.readyState != 1)
            throw WebSocket.Error('websocket is disconnected')
        ptr := (cache := Buffer(size := this.__cache_size)).Ptr, offset := 0
        while (!err := DllCall('Winhttp\WinHttpWebSocketReceive', 'ptr', this, 'ptr', ptr + offset, 'uint', size -
            offset, 'uint*', &dwBytesRead := 0, 'uint*', &eBufferType := 0)) {
            switch eBufferType {
                case 1, 3:
                    offset += dwBytesRead
                    if offset == size
                        cache.Size := size *= 2, ptr := cache.Ptr
                case 0, 2:
                    offset += dwBytesRead
                    if eBufferType == 2
                        return StrGet(ptr, offset, 'utf-8')
                    cache.Size := offset
                    return cache
                case 4:
                    rea := this.QueryCloseStatus(), this.shutdown()
                    try this.onClose(rea.status, rea.reason)
                    return
            }
        }
        (err != 4317 && this.onError(err))
    }

    shutdown() {
        if (this.readyState = 1) {
            this.readyState := 2
            DllCall('Winhttp\WinHttpWebSocketClose', 'ptr', this, 'ushort', 1006, 'ptr', 0, 'uint', 0)
            this.readyState := 3
        }
        while (this.HINTERNETs.Length > 2)
            DllCall('Winhttp\WinHttpCloseHandle', 'ptr', this.HINTERNETs.Pop())
        this.Ptr := 0
    }
}
