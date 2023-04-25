module GitlabCIMain
using GitLabCISub1
using GitLabCISub2

"""
    get_cylinder_area(radius, height)

Get the area of a cylinder by a given radius and height.
"""
function get_cylinder_area(radius, height)
    return 2 * GitLabCISub1.get_circle_area(radius) + GitLabCISub2.get_rectangle_area(GitLabCISub1.get_circle_circumference(radius), height)
end

"""
    get_cylinder_volume(radius, height)

Get the circumference of a rectangle by a given radius.
"""
function get_cylinder_volume(radius, height)
    return GitLabCISub1.get_circle_area(radius) * height
end

end

