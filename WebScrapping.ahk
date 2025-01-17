#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Chrome.ahk
SetTitleMatchMode 2


class WebScrapping {
    __New() {
        this.working := true
        this.navigator := Chrome()
        if !WinExist("ahk_exe chrome.exe")
            WinWait("ahk_exe chrome.exe")
        this.page := false
        this.working := false
    }

    WaitForLoad(){
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
        this.page := this.navigator.GetPage()
        if !this.CheckPage()
            return false
        return true
    }

    SetPageByTitle(title) {
        this.page := this.navigator.GetPageByTitle(title, 'contains')
        return this.CheckPage()
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
