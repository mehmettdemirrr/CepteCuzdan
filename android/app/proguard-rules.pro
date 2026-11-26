# google_mlkit_text_recognition yalnızca Latin alfabesiyle kullanılıyor;
# kullanılmayan isteğe bağlı alfabe modülleri için R8 uyarılarını sustur.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
