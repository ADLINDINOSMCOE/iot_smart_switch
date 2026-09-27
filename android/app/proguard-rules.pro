# Flutter-related rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Firebase rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Keep Firestore classes
-keep class com.google.firebase.firestore.** { *; }

# Keep Auth classes
-keep class com.google.firebase.auth.** { *; }

# Keep Messaging classes
-keep class com.google.firebase.messaging.** { *; }

# Keep Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}