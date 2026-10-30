# kotlinx.serialization ships its own rules. These keep the generated serializers of the contract models.
-keepclassmembers class com.lucferbux.embalsesanjuan.data.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
