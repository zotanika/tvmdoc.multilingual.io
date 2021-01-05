TVM Multilingual Documentation
===============================

- - -

Introduction
------------
This project has been established to provide a workplace for [TVM technical documentation](https://tvm.apache.org/docs/) localization.
For now, primary target languages are Korean, Japanese, and Chinese(simplified).

Setup
-----
Volunteers can immediately start translating just after cloning the project repository by: 
```
$ git clone --recursive https://github.com/zotanika/tvmdoc.multilingual.io
$ cd ./tvmdoc.multilingual.io
```

Advanced Setup
-------------
For your convenience, please prepare the virtual environment for keeping your workspace quarantined from the global system environment(limited to Linux environment):
```
$ virtualenv -p python3.7 ./venv
$ . ./venv/bin/activate
$ pip install -r requirements.txt
```
One more step will be required, to make HTML preview reflecting your efforts possible:
```
$ . makeready.sh
```

Target Files
------------
Please check in **PO**(text based portable object) files from the directory `./locale/<lang>/LC_MESSAGES/`. Simply, each translator can fill the **blank msgstr**s.

| **Language** | **Working Directory** |
|----------|-------------------|
| Korean | ./locale/kr/LC_MESSAGES/ |
| Japanese | ./locale/ja/LC_MESSAGES/ |
| Chinese(simplified) | ./locale/zh_CN/LC_MESSAGES/ |

An example snippet in `./locale/<lang>/LC_MESSAGES/faq.po` follows, where the msgid is multi-line text and contains reStructuredText syntax.
```
#: ../../faq.rst:31
msgid ""
"If the hardware backend has LLVM support, then we can directly generate "
"the code by setting the correct target triple as in "
":py:mod:`~tvm.target`."
msgstr ""
"<FILL HERE WITH TARGET LANGUAGE>"
```
For Korean,
```
#: ../../faq.rst:31
msgid ""
"If the hardware backend has LLVM support, then we can directly generate "
"the code by setting the correct target triple as in "
":py:mod:`~tvm.target`."
msgstr ""
"만일 타겟 하드웨어 백엔드가 LLVM을 지원한다면, :py:mod:`~tvm.target` 에 적절한 "
"타겟 트리플을 지정함으로써 곧바로 코드를 생성할 수 있습니다."
```
Further references could be found at [SPHINX internationalization](https://www.sphinx-doc.org/en/master/usage/advanced/intl.html) process.

HTML preview
------------
Volunteers are able to preview how their translations appear in actual HTML pages by running:      
- For Korean
```
$ . makehtml_kr.sh
```
- For Japanese
```
$ . makehtml_jp.sh
```
- For Chinese(simplified)
```
$ . makehtml_zh_CN.sh
```
Then open `./html/index.html` with a web browser.

Check out TVM upstream
-------------
In case that you would like to see what updates may be delivered from upstream TVM documentations, please run the script:
```
$ . upsync.sh
```
The process above will help you update and build the whole upstream TVM project, then generate latest PO files correspondingly.
You can find the updated HTML artifacts at `./html-reference` (in English).