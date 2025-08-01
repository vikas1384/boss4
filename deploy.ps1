# Deployment script for Arogya AI
param(
    [Parameter(Mandatory=$true)]
    [string]$GITHUB_TOKEN
)

# Function to validate token
function Test-GitHubToken {
    param([string]$Token)
    
    try {
        $headers = @{
            'Authorization' = "Bearer $Token"
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        $response = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers
        Write-Host "GitHub token validated successfully for user: $($response.login)"
        return $true
    }
    catch {
        Write-Error "Failed to validate GitHub token: $_"
        return $false
    }
}

# Function to start application deployment
function Start-ApplicationDeployment {
    param([string]$Token)
    
    try {
        # Validate environment
        if (-not (Test-Path .env.production)) {
            throw "Production environment file not found"
        }

        # Install dependencies
        Write-Host "Installing dependencies..."
        npm ci --production

        # Run build
        Write-Host "Building application..."
        npm run build

        # Use the GitHub token for deployment
        if (Test-GitHubToken -Token $Token) {
            # Set up git configuration
            git config --global user.name "GitHub Actions"
            git config --global user.email "actions@github.com"
            
            # Add production files
            git add dist/ -f
            git commit -m "Deploy: Production build"
            
            # Push to deployment branch using the token
            $repoUrl = "https://${Token}@github.com/vikas1384/boss4.git"
            git push $repoUrl production -f
            
            Write-Host "Deployment completed successfully"
            return $true
        }
        else {
            throw "GitHub token validation failed"
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        return $false
    }
}

# Main execution
Write-Host "Starting deployment process..."
if (Start-ApplicationDeployment -Token $GITHUB_TOKEN) {
    Write-Host "Deployment completed successfully"
    exit 0
} else {
    Write-Error "Deployment failed"
    exit 1
}
