#Requires AutoHotkey v2.0
#SingleInstance Force

#include WebScrapping.ahk
web_scrap := WebScrapping()

f10::{
    if !web_scrap.SetPageByTitle("Google") {
        web_scrap.SetAnyPage()
        web_scrap.Navigate("https://www.google.com/", true)
    }
    web_scrap.SendJS("alert('Hello from AHK!');")
    search_element := "document.querySelectorAll('textarea')[0]"
    search_button := "document.querySelectorAll('center>input[role=`"button`"]')[1]"
    web_scrap.SimulatePaste(search_element, "ositomalvado")
    web_scrap.ClickElement(search_button, "left", 1)
    first_item := "document.querySelectorAll('div>div>span>a>h3')[0]"
    while !web_scrap.GetElement(first_item)
        Sleep 100
    web_scrap.ClickElement(first_item, "left", 1)
    web_scrap_repo := "document.querySelectorAll('span>a[data-view-component=`"true`"]>span')[4]"
    while !web_scrap.GetElement(web_scrap_repo)
        Sleep 100
    web_scrap.ClickElement(web_scrap_repo, "left", 1)
    web_scrap.WaitForLoad()
    js_injection := "const greetings = 'greetings from Argentina'"
    web_scrap.SendJS(js_injection)
    MsgBox web_scrap.SendJS("greetings")["value"]
    text := "Thank you for watching from AHK!"
    web_scrap.SendJS("alert('" text "')")
}