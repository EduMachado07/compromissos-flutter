# O Flutter ativa o R8 nos builds de release e inclui este arquivo
# automaticamente. O device_calendar serializa as classes dele com gson, por
# reflexão; sem esta regra o R8 remove/renomeia os campos e retrieveCalendars()
# devolve calendários vazios. Veja o README do plugin.
-keep class com.builttoroam.devicecalendar.** { *; }
