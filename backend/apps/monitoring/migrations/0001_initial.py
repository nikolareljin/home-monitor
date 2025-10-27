# Generated manually by Codex for initial schema.
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='SensorDevice',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=255)),
                ('slug', models.SlugField(unique=True)),
                ('manufacturer', models.CharField(blank=True, max_length=255)),
                ('sensor_type', models.CharField(choices=[('radon', 'Radon'), ('temperature', 'Temperature'), ('humidity', 'Humidity'), ('air_quality', 'Air Quality'), ('custom', 'Custom')], max_length=50)),
                ('connection_type', models.CharField(default='api', max_length=50)),
                ('metadata', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={'ordering': ['name']},
        ),
        migrations.CreateModel(
            name='Recommendation',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('category', models.CharField(max_length=100)),
                ('message', models.TextField()),
                ('confidence', models.FloatField(blank=True, null=True)),
                ('context', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('device', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='recommendations', to='monitoring.sensordevice')),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='SensorReading',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('metric', models.CharField(max_length=100)),
                ('value', models.FloatField()),
                ('unit', models.CharField(max_length=32)),
                ('timestamp', models.DateTimeField()),
                ('raw_payload', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('device', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='readings', to='monitoring.sensordevice')),
            ],
            options={'ordering': ['-timestamp']},
        ),
        migrations.AddIndex(
            model_name='sensorreading',
            index=models.Index(fields=['device', 'metric', 'timestamp'], name='monitoring_device__b4b966_idx'),
        ),
    ]
