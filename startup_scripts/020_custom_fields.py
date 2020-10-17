import sys

from extras.models import CustomField
from startup_script_utils import load_yaml

def get_class_for_class_path(class_path):
  import importlib
  from django.contrib.contenttypes.models import ContentType

  module_name, class_name = class_path.rsplit(".", 1)
  module = importlib.import_module(module_name)
  clazz = getattr(module, class_name)
  return ContentType.objects.get_for_model(clazz)

customfields = load_yaml('/opt/netbox/initializers/custom_fields.yml')

if customfields is None:
  sys.exit()

for cf_name, cf_details in customfields.items():
  custom_field, created = CustomField.objects.get_or_create(name = cf_name)

  if created:
    if cf_details.get('default', False):
      custom_field.default = cf_details['default']

    if cf_details.get('description', False):
      custom_field.description = cf_details['description']

    if cf_details.get('label', False):
      custom_field.label = cf_details['label']

    for object_type in cf_details.get('on_objects', []):
      custom_field.content_types.add(get_class_for_class_path(object_type))

    if cf_details.get('required', False):
      custom_field.required = cf_details['required']

    if cf_details.get('type', False):
      custom_field.type = cf_details['type']

    if cf_details.get('weight', -1) >= 0:
      custom_field.weight = cf_details['weight']

    if cf_details.get('choices', False):
      custom_field.choices = []

      for _, choice_detail in enumerate(cf_details.get('choices', [])):
        if isinstance(choice_detail, str):
          custom_field.choices.append(choice_detail)
        else:  # legacy mode
          print(f"⚠️ Please migrate the 'choices' of '{cf_name}' to the new format, as 'weight' is no longer supported!")
          custom_field.choices.append(choice_detail['value'])

    custom_field.save()

    print("🔧 Created custom field", cf_name)
