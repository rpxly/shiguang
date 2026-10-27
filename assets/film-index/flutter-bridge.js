(function () {
  window.addImagesFromFlutter = async function (images) {
    if (!window.__filmIndexLoadFiles) {
      console.error('filmIndex: app.js not ready yet');
      return;
    }
    const files = [];
    for (let i = 0; i < images.length; i++) {
      try {
        const resp = await fetch(images[i].data);
        const blob = await resp.blob();
        const file = new File([blob], images[i].name || 'photo_' + Date.now() + '.jpg', { type: blob.type });
        files.push(file);
      } catch (e) {
        console.error('filmIndex: failed to process image', i, e);
      }
    }
    if (files.length > 0) {
      window.__filmIndexLoadFiles(files);
    }
  };

  window.filmIndexVersion = '1.0.0';
})();
