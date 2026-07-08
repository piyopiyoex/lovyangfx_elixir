ExUnit.start(exclude: [:native, :framebuffer, :target])

Mox.defmock(LovyanGFX.MockBackend, for: LovyanGFX.Backend)
