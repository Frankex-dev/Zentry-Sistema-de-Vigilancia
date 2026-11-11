from django.conf import settings
from django.contrib import admin
from django.urls import include, path

admin.site.site_header = 'Zentry · Administración'
admin.site.site_title = 'Zentry'
admin.site.index_title = 'Datos del sistema'

urlpatterns = [
    path('admin/', admin.site.urls),
] + [path('', include(f'{modulo}.urls')) for modulo in settings.MODULOS_ZENTRY]
