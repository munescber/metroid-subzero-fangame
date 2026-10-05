extends Bullet

class_name ChargeBeam

# Charged version of the normal Bullet. Movement, lifetime and hit handling are
# inherited; this scene only overrides damage/size/visuals (see charge_beam.tscn).
# Extending Bullet also keeps it recognised as a player projectile
# (e.g. activation_button.gd checks `is Bullet`).
