#Requires AutoHotkey v2.0
#SingleInstance Force

#include WebScrapping.ahk
web_scrap := WebScrapping()
; web_scrap := WebScrapping(chrome_path := "C:\Users\Julian\AppData\Local\Chromium\Application\chrome.exe")

f10::{
    ToolTip "Setting Page"
    if !web_scrap.SetPageByURL("https://www.google.com/") {
        web_scrap.SetAnyPage()
        web_scrap.Navigate("https://www.google.com/", true)
    }
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
    ToolTip "Waiting for load"
    Sleep 500
    web_scrap.WaitForLoad()
    loop 10{
        ToolTip "Scrolling to bottom"
        web_scrap.Scroll("bottom")
        Sleep 10
        ToolTip "Scrolling to top"
        web_scrap.Scroll("top")
        Sleep 10
    }
    ToolTip "Closing"
    web_scrap.Close()
    web_scrap.Kill()
    Sleep 1000
    ToolTip
}