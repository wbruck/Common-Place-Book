# The google_mlkit_text_recognition plugin references the optional
# script-specific recognizers (Chinese, Devanagari, Japanese, Korean) even when
# only the Latin model is bundled. The app never instantiates them, so R8 just
# needs to be told the missing classes are expected.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
