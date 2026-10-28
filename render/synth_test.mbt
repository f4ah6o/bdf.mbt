///|
test "MIDI channel state preserves unaffected controls on reset" {
  let state = @render.initial_channel()
  assert_true(
    @render.apply_channel_event(state, @core.Program(channel=3, program=80)),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=7, value=64),
    ),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=10, value=0),
    ),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=70, value=40),
    ),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=11, value=90),
    ),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=64, value=127),
    ),
  )
  assert_true(
    @render.apply_channel_event(state, @core.Bend(channel=3, value=4096)),
  )
  assert_true(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=121, value=0),
    ),
  )
  assert_eq(
    (state.program, state.volume, state.pan, state.duty),
    (80, 64, 0, 40),
  )
  assert_eq((state.expression, state.sustain, state.bend), (127, false, 0))
  assert_false(
    @render.apply_channel_event(
      state,
      @core.Control(channel=3, controller=12, value=5),
    ),
  )
}

///|
test "MIDI programs and square duty select the expected timbres" {
  assert_eq(@render.pulse_duty(31), 0.5)
  assert_eq(@render.pulse_duty(32), 0.125)
  assert_eq(@render.pulse_duty(64), 0.25)
  assert_eq(@render.pulse_duty(96), 0.75)
  assert_eq(@render.patch_of(0).wave, "piano")
  assert_eq(@render.patch_of(19).wave, "organ")
  assert_eq(@render.patch_of(55).wave, "sawtooth")
  assert_eq(@render.patch_of(79).wave, "sine")
  assert_eq(@render.patch_of(80).wave, "pulse")
  assert_eq(@render.patch_of(81).wave, "sawtooth")
  assert_eq(@render.patch_of(82).wave, "triangle")
  assert_eq(@render.patch_of(122).wave, "noise")
  assert_eq(@render.patch_of(0).sustain, 0.0)
  assert_eq(@render.patch_of(19).sustain, 1.0)
  for program in 0..<128 {
    assert_true(@render.patch_of(program).gain > 0.0)
  }
}
