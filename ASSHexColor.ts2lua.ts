interface RGBStringValue extends String
{
    ___brand?: string | undefined
}
interface HexChar extends String {
    ___char_brand?: string | undefined
}

class ASSColorData
{
    r: string;
    g: string;
    b: string;

    constructor(r: string, g: string, b: string);
    constructor(BGR: string);
    constructor(...values: [string] | [string, string, string])
    {
        const arg_count = values.length;
        if(arg_count === 1)
        {
            let rgbRaw = values[0];
            if(rgbRaw.length === 3)
            {
                // Just double up chars for #BGR format
                // (Believe its invalid, but useful shorthand)
                const b: string = rgbRaw[0] + rgbRaw[0],
                      g: string = rgbRaw[1] + rgbRaw[1],
                      r: string = rgbRaw[2] + rgbRaw[2];

                for(const value of [r, g, b])
                {
                    if(!isValidRGBHexComponent(value))
                    {
                        error('Invalid BGR component: ' + value)
                    }
                }

                this.r = r;
                this.g = g;
                this.b = b;

                return
            }
            else if(rgbRaw.length === 6)
            {
                const b = rgbRaw.slice(0, 1),
                      g = rgbRaw.slice(2, 3),
                      r = rgbRaw.slice(4, 5)

                for(const value of [r, g, b])
                {
                    if(!isValidRGBHexComponent(value))
                    {
                        error('Invalid BGR component: ' + value)
                    }
                }

                this.r = r;
                this.g = g;
                this.b = b;
            }
            else
            {
                throw ""
                // @ts-expect-error
                return undefined
            }

            throw ""

            return
            ;;
        }
        else if(arg_count === 3)
        {
            const [r, g, b] = values as [string, string, string];

            for(const value of [r, g, b])
            {
                if(!isValidRGBHexComponent(value))
                {
                    error('Invalid BGR component: ' + value)
                }
            }

            this.r = r;
            this.g = g;
            this.b = b;

            return
            ;;
        }
        else
        {
            throw ""
            // @ts-expect-error
            return undefined
        }
    }

    toString(): string
    {
        return this.toString()
    };

    toEsc():    string
    {
        return (({r,g,b}) => `${b}${g}${r}`)(this)
    };
}

/**
 * Validate a R/G/B value string
 */
function isValidRGBHexComponent(value: unknown): value is RGBStringValue
{
    return (
        typeof value === 'string'
        && value.length === 2
        && isHexDigit(value[0])
        && isHexDigit(value[1])
    )
}
// @TODO: Implement regex matching after transpilation
function isHexDigit(char: unknown): char is HexChar
{
    return (
        typeof (char) === 'string'
        && char.length === 1
        && ((charCode: number) =>
               // 0-9
            (charCode >= 48 && charCode <= 57)
            || // A-F
            (charCode >= 65 && charCode <= 70)
            || // a-f
            (charCode >= 97 && charCode <= 102)
        )(char.charCodeAt(0))
    )
}

let color = new ASSColorData('FF', 'FF', '00')
