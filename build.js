const fs = require('fs').promises;
const path = require('path');
const { minify } = require('terser');

async function minifyJS(filePath) {
    const code = await fs.readFile(filePath, 'utf8');
    const minified = await minify(code, {
        compress: {
            dead_code: true,
            drop_console: true,
            drop_debugger: true,
            keep_fnames: false,
            passes: 2
        },
        mangle: true
    });
    await fs.writeFile(filePath.replace('.js', '.min.js'), minified.code);
    console.log(`Minified ${filePath}`);
}

async function build() {
    try {
        console.log('Starting build process...');
        
        // Minify JavaScript files
        await minifyJS(path.join(__dirname, 'script.js'));
        
        // Create production directory
        const distDir = path.join(__dirname, 'dist');
        await fs.mkdir(distDir, { recursive: true });
        
        // Copy and optimize files
        const filesToCopy = ['index.html', 'styles.css', 'favicon.svg', 'script.min.js'];
        for (const file of filesToCopy) {
            if (file.endsWith('.min.js')) {
                await fs.copyFile(
                    path.join(__dirname, file),
                    path.join(distDir, file.replace('.min.js', '.js'))
                );
            } else {
                await fs.copyFile(
                    path.join(__dirname, file),
                    path.join(distDir, file)
                );
            }
        }
        
        // Update index.html to use minified scripts
        let indexHtml = await fs.readFile(path.join(distDir, 'index.html'), 'utf8');
        indexHtml = indexHtml.replace('script.js', 'script.min.js');
        await fs.writeFile(path.join(distDir, 'index.html'), indexHtml);
        
        console.log('Build completed successfully!');
    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

build();
