import re

with open('scenes/enemies/axolotl_enemy.tscn', 'r') as f:
    content = f.read()

# Replace Visuals Node3D with SegmentedSpriteRig
content = content.replace('[node name="Visuals" type="Node3D" parent="."]', '[node name="Visuals" type="Node3D" parent="." script=ExtResource("rig_script")]')
if 'ext_resource type="Script"' not in content and 'segmented_sprite_rig.gd' not in content:
    content = content.replace('[ext_resource', '[ext_resource type="Script" uid="uid://rig123" path="res://scripts/components/segmented_sprite_rig.gd" id="rig_script"]\n[ext_resource', 1)

# Change Sprite3D to RigPart3D for Body, Tail, Head, Whiskers
for sprite in ['SpriteTail', 'SpriteBody', 'SpriteHead', 'SpriteWhiskers']:
    content = content.replace(f'[node name="{sprite}" type="Sprite3D"', f'[node name="{sprite}" type="Sprite3D" script=ExtResource("part_script")]')

if 'rig_part_3d.gd' not in content:
    content = content.replace('[ext_resource', '[ext_resource type="Script" uid="uid://part123" path="res://scripts/components/rig_part_3d.gd" id="part_script"]\n[ext_resource', 1)

with open('scenes/enemies/axolotl_enemy.tscn', 'w') as f:
    f.write(content)
print('Migration complete.')
