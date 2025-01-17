#Requires AutoHotkey v2.0
#SingleInstance Force

#include WebScrapping.ahk
web_scrap := WebScrapping()

f10::{
    ToolTip "Setting Page"
    if !web_scrap.SetPageByTitle("Google") {
        web_scrap.SetAnyPage()
        web_scrap.Navigate("https://www.google.com/", true)
    }
    ToolTip "Injecting JS"
    ; web_scrap.SendJS("alert('Hello from AHK!');")
    search_element := "document.querySelectorAll('textarea')[0]"
    search_button := "document.querySelectorAll('center>input[role=`"button`"]')[1]"
    ToolTip "Searching"
    web_scrap.SimulatePaste(search_element, "ositomalvado")
    web_scrap.ClickElement(search_button, "left", 1)
    first_item := "document.querySelectorAll('div>div>span>a>h3')[0]"
    ToolTip "Waiting for item"
    while !web_scrap.GetElement(first_item)
        Sleep 100
    ToolTip "Clicking item"
    web_scrap.ClickElement(first_item, "left", 1)
    web_scrap_repo := "document.querySelectorAll('span>a[data-view-component=`"true`"]>span')[4]"
    ToolTip "Waiting for repo"
    while !web_scrap.GetElement(web_scrap_repo)
        Sleep 100
    ToolTip "Clicking repo"
    web_scrap.ClickElement(web_scrap_repo, "left", 1)
    web_scrap.WaitForLoad()
    js_injection := "const greetings = 'greetings from Argentina'"
    ToolTip "Injecting JS"
    web_scrap.SendJS(js_injection)
    ToolTip "Getting value from JS"
    MsgBox web_scrap.SendJS("greetings")["value"]
    text := "Thank you for watching from AHK!"
    ToolTip "Sending alert with AHK variable value"
    web_scrap.SendJS("alert('" text "')")
    ToolTip "Waiting for load"
    web_scrap.WaitForLoad()
    loop 10{
        ToolTip "Scrolling to bottom"
        web_scrap.Scroll("bottom")
        Sleep 100
        ToolTip "Scrolling to top"
        web_scrap.Scroll("top")
        Sleep 100
    }
    ToolTip "Closing"
    web_scrap.Close()
    Sleep 1000
    ToolTip
}