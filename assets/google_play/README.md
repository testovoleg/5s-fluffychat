# Google Play image assets

Source images used by the generation scripts live in `source/`:

```text
source/
├── feature_graphic_template.png
├── phone/
│   ├── login_light.png
│   ├── login_dark.png
│   └── chat_list.png
└── tablet/
    ├── login_light.png
    ├── login_dark.png
    └── chat_list.png
```

Generated store-ready files are written to `publish/` and
`feature_graphic.png`. The scripts remove the Flutter DEBUG ribbon while
rendering, so the source screenshots can be captured from a debug build.

Run the generators from any working directory:

```shell
python scripts/build-google-play-screenshots.py
python scripts/build-google-play-feature-graphic.py
```

Both scripts require Pillow.
