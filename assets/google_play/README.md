# Google Play image assets

Source images used by the generation scripts live in `source/`:

```text
source/
├── feature_graphic_template.png
├── phone/          # Samsung Galaxy S8+
│   ├── login_light.png
│   ├── login_dark.png
│   └── chat_list.png
└── tablet/         # iPad Mini
    ├── login_light.png
    ├── login_dark.png
    └── chat_list.png
```

Capture phone screenshots on a **Samsung Galaxy S8+** emulator/device and
tablet screenshots on an **iPad Mini**. Generated store-ready files are
written to `publish/` and `feature_graphic.png`.

Run the generators from any working directory:

```shell
python scripts/build-google-play-screenshots.py
python scripts/build-google-play-feature-graphic.py
```

Both scripts require Pillow.
