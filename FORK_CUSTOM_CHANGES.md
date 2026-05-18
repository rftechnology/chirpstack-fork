# Custom changes (simple summary)

**Technical implementation (one sentence per topic)**  
- **Join timing (US915):** The US915 stack defaults shorten the two JoinAccept receive delays from 5s/6s to **1s/2s** so the radio firmware stops listening for the join reply sooner.  
- **Downlink scheduling & ADR:** Configuration sets **RX1-only** Class A downlinks and turns **ADR off**, so the server schedules the first downlink window and does not drive automatic data-rate changes via MAC.  
- **Special “control” downlinks (FPort 99):** If the downlink queue says **FPort 99**, the server builds an on-air **FPort 0** frame payload and encrypts it with the **network session encryption key (NwkSEnc)** instead of the application key when the queued payload is not already encrypted.  
- **Uplink matching that downlink:** On uplink **FPort 0**, the server decrypts the frame payload using a **dedicated NwkSEnc decrypt path** so it matches how those redirected downlinks were encrypted.  
- **“Ack / clear” messages and the device queue:** When the payload text starts with **`RFTA` or `RFTC`**, the server **pushes the device’s DevEUI onto a Redis list** during downlink handling, and on the **next uplink** it **checks that list**, **flushes the device’s entire downlink queue in the database**, then **removes the DevEUI from Redis**.

---

**Join timing (US915)**  
Join-response listen windows are shortened so devices wait less during join, but the network must answer quickly. This speeds up getting devices online after power-up or install.

**Downlink scheduling & ADR**  
Class A downlinks use the first receive window only, and automatic data-rate tuning (ADR) is turned off for this profile. That makes radio behavior more fixed and predictable, instead of the network constantly adjusting rate and power.

**Special “control” downlinks (FPort 99)**  
When a downlink is queued with a reserved internal port (99), the system sends it over the air like ordinary network-side payload (port 0) and encrypts it like network traffic, not like normal application data. That matches devices whose firmware expects control messages in that form.

**Uplink matching that downlink**  
Uplink frames with the same kind of network-style payload are decrypted the matching way so devices and the server stay in sync. Without that, uplinks after those downlinks would not decode correctly.

**“Ack / clear” messages and the device queue**  
If a downlink payload begins with specific agreed text (`RFTA` or `RFTC`), the device’s DevEUI is noted, and on the **next uplink** the network **empties all pending downlinks** for that device. That prevents old, queued commands from being delivered after an acknowledge-or-clear step is done.
