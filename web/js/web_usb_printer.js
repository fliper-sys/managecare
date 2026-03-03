// Minimal WebUSB helper for ESC/POS thermal printers
// Exposes a `webUsbPrinter` object on window with methods:
// - requestPrinter(filters) -> {deviceId, vendorId, productId, productName}
// - listDevices() -> array of devices
// - sendToPrinter(deviceId, base64Data) -> bytes sent
// - closePrinter(deviceId)

(function () {
  const devices = {}; // deviceId -> {device}

  function _makeId(device) {
    return `${device.vendorId}:${device.productId}:${device.serialNumber || device.productName || Math.random().toString(36).slice(2)}`;
  }

  async function _openDevice(device) {
    if (!device.opened) {
      try {
        await device.open();
      } catch (e) {
        if (e.name === 'NotAllowedError') {
          throw new Error('USB Access Denied: Cannot open printer. Browser permission may have been revoked. Try selecting the device again.');
        }
        if (e.name === 'SecurityError') {
          throw new Error('Security Error: WebUSB access denied. Ensure the page is HTTPS or localhost, not HTTP or incognito mode.');
        }
        throw e;
      }
    }

    if (device.configuration === null) {
      try {
        await device.selectConfiguration(1);
      } catch (e) {
        // Some printers may not require explicit configuration selection
      }
    }

    // claim first interface with an OUT endpoint
    const interfaces = device.configuration?.interfaces || [];
    if (interfaces.length === 0) {
      // Device has no interfaces, might still work with controlTransfer
      return null;
    }

    for (const iface of interfaces) {
      for (const alt of iface.alternates) {
        for (const ep of (alt.endpoints || [])) {
          if (ep.direction === 'out') {
            try {
              await device.claimInterface(iface.interfaceNumber);
              return {interfaceNumber: iface.interfaceNumber, endpointNumber: ep.endpointNumber};
            } catch (e) {
              // ignore claim errors and try next
            }
          }
        }
      }
    }

    // If no out endpoint found, still continue; some devices accept controlTransferOut
    return null;
  }

  async function requestPrinter(filters) {
    if (!navigator.usb) throw new Error('WebUSB not available in this browser');
    try {
      // filters is expected to be an array of objects like {vendorId: 0x04b8}
      const device = await navigator.usb.requestDevice({ filters: filters || [] });
      const id = _makeId(device);
      devices[id] = { device };
      return { deviceId: id, vendorId: device.vendorId, productId: device.productId, productName: device.productName };
    } catch (e) {
      if (e.name === 'NotAllowedError') {
        throw new Error('USB Access Denied: User did not grant permission to access the printer. Please try again and allow access when prompted.');
      }
      throw e;
    }
  }

  async function listDevices() {
    if (!navigator.usb) return [];
    
    try {
      // getDevices() only returns devices with previous permission
      const found = await navigator.usb.getDevices();
      const result = [];
      
      for (const device of found) {
        const id = _makeId(device);
        devices[id] = { device };
        result.push({ 
          deviceId: id, 
          vendorId: device.vendorId, 
          productId: device.productId, 
          productName: device.productName 
        });
      }
      
      return result;
    } catch (e) {
      console.warn('WebUSB listDevices error:', e);
      return [];
    }
  }

  function _base64ToUint8Array(base64) {
    const raw = atob(base64);
    const arr = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
    return arr;
  }

  async function sendToPrinter(deviceId, base64Data) {
    const entry = devices[deviceId];
    if (!entry) throw new Error('Device not found');
    const device = entry.device;

    const data = _base64ToUint8Array(base64Data);

    try {
      const iface = await _openDevice(device);

      if (iface && iface.endpointNumber != null) {
        // chunk into 64k for safe transfers
        const CHUNK = 65536;
        let sent = 0;
        for (let i = 0; i < data.length; i += CHUNK) {
          const slice = data.subarray(i, Math.min(i + CHUNK, data.length));
          try {
            const res = await device.transferOut(iface.endpointNumber, slice);
            if (res.status !== 'ok') throw new Error('Transfer failed: ' + res.status);
            sent += slice.length;
          } catch (e) {
            if (e.name === 'NotAllowedError' || e.name === 'SecurityError' || e.message.includes('Access denied')) {
              throw new Error('USB Access Denied: The printer requires permission. Please re-select the printer in settings.');
            }
            throw e;
          }
        }
        return sent;
      } else {
        // Try control transfer as fallback
        try {
          const res = await device.controlTransferOut({ requestType: 'class', recipient: 'interface', request: 0x09, value: 0x0200, index: 0 }, data);
          if (res && res.status === 'ok') return data.length;
          throw new Error('No suitable OUT endpoint and control transfer failed');
        } catch (e) {
          if (e.name === 'NotAllowedError' || e.name === 'SecurityError' || e.message.includes('Access denied')) {
            throw new Error('USB Access Denied: The printer requires permission. Please re-select the printer in settings.');
          }
          throw e;
        }
      }
    } catch (e) {
      throw e;
    }
  }

  async function closePrinter(deviceId) {
    const entry = devices[deviceId];
    if (!entry) return false;
    const device = entry.device;
    try {
      // release interfaces
      if (device.configuration && device.configuration.interfaces) {
        for (const iface of device.configuration.interfaces) {
          try { await device.releaseInterface(iface.interfaceNumber); } catch (e) {}
        }
      }
      if (device.opened) await device.close();
      delete devices[deviceId];
      return true;
    } catch (e) {
      return false;
    }
  }

  // Expose a convenience function to convert text to ESC/POS bytes on the browser
  function textToEscPosBase64(text) {
    // Create ESC @, text in UTF-8 (printer may expect CP437/437 or Latin1), then feed and cut
    const esc = new Uint8Array([0x1b, 0x40]); // initialize
    const encoder = new TextEncoder();
    const body = encoder.encode(text + '\n\n\n');
    const cut = new Uint8Array([0x1d, 0x56, 0x00]); // GS V 0 (full cut) may work

    const all = new Uint8Array(esc.length + body.length + cut.length);
    all.set(esc, 0);
    all.set(body, esc.length);
    all.set(cut, esc.length + body.length);

    // base64
    let str = '';
    for (let i = 0; i < all.length; i++) str += String.fromCharCode(all[i]);
    return btoa(str);
  }

  // Attach to window
  window.webUsbPrinter = {
    requestPrinter,
    listDevices,
    sendToPrinter,
    closePrinter,
    textToEscPosBase64,
  };
})();
