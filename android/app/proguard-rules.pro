# MediaPipe's LLM runtime references AutoValue annotations that are not shipped
# in the AAR; they are compile-time only, so R8 can ignore them.
-dontwarn com.google.auto.value.AutoValue
-dontwarn com.google.auto.value.AutoValue$Builder

# MediaPipe reads AutoValue fields reflectively and calls into JNI; renaming
# these classes or their members breaks model loading at runtime.
-keep class com.google.mediapipe.tasks.genai.** { *; }
-keepclassmembers class com.google.mediapipe.tasks.genai.** { *; }

# tasks-genai references tasks-core image helpers it never uses for text-only
# inference, and tasks-core is not a declared dependency.
-dontwarn com.google.mediapipe.framework.image.**
